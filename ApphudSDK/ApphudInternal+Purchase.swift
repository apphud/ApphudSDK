//
//  ApphudInternal+Purchase.swift
//  apphud
//
//  Created by Renat on 01.07.2020.
//  Copyright © 2020 Apphud Inc. All rights reserved.
//

import Foundation
import StoreKit

@available(OSX 10.14.4, *)
extension ApphudInternal {

    // MARK: - Main Purchase and Submit Receipt methods

    internal func restorePurchases(callback: @escaping ([ApphudSubscription]?, [ApphudNonRenewingPurchase]?, Error?) -> Void) {
        self.restorePurchasesCallback = { subs, purchases, error in
            if error != nil { ApphudStoreKitWrapper.shared.restoreTransactions() }
            callback(subs, purchases, error)
        }
        self.submitReceiptRestore(allowsReceiptRefresh: true, transaction: nil)
    }
    
    internal func setNeedToCheckTransactions() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(checkTransactionsNow), object: nil)
        perform(#selector(checkTransactionsNow), with: nil, afterDelay: 3)
    }
    
    @objc private func checkTransactionsNow() {
        
        guard !Apphud.hasPremiumAccess() && !ApphudStoreKitWrapper.shared.isPurchasing else {
            return
        }
        
        if #available(iOS 15.0, tvOS 15.0, watchOS 8.0, macOS 12.0, *) {
            Task {
                for await result in StoreKit.Transaction.currentEntitlements {
                    if case .verified(let transaction) = result {
                        let transactionId = transaction.id
                        let refundDate = transaction.revocationDate
                        let expirationDate = transaction.expirationDate
                        let purchaseDate = transaction.purchaseDate
                        let upgrade = transaction.isUpgraded
                        let productID = transaction.productID
                        
                        guard !self.lastUploadedTransactions.contains(transactionId) else {
                            continue
                        }
                                
                        var isActive = false
                        switch transaction.productType {
                        case .autoRenewable:
                            isActive = expirationDate != nil && expirationDate! > Date() && refundDate == nil && upgrade == false
                        default:
                            isActive = purchaseDate > Date().addingTimeInterval(-86_400) && refundDate == nil
                        }
                        
                        if isActive {
                            apphudLog("found transaction with ID: \(transactionId), purchase date: \(purchaseDate)", logLevel: .debug)
                            self.isSubmittingReceipt = false
                            self.submitReceipt(product: nil,
                                               apphudProduct: nil,
                                               transactionIdentifier: String(transactionId),
                                               transactionProductIdentifier: productID,
                                               transactionState: nil,
                                               receiptString: apphudReceiptDataString(),
                                               notifyDelegate: true) { [self] error in
                                if error == nil {
                                    self.lastUploadedTransactions.append(transactionId)
                                }
                            }
                            
                            break
                        }
                    }
                }
            }
        }
    }

    internal func submitReceiptAutomaticPurchaseTracking(transaction: SKPaymentTransaction, callback: @escaping ((ApphudPurchaseResult) -> Void)) {

        performWhenUserRegistered {
            
            let receiptString = apphudReceiptDataString()
            
            if receiptString == nil {
                apphudLog("App Store receipt is missing, but got transaction. Will try to submit transaction instead..", forceDisplay: true)
            }

            self.submitReceipt(product: nil, apphudProduct: nil, transaction: transaction, receiptString: receiptString, notifyDelegate: true, eligibilityCheck: true, callback: { error in
                let result = self.purchaseResult(productId: transaction.payment.productIdentifier, transaction: transaction, error: error)
                callback(result)
            })
        }
    }

    @objc internal func submitAppStoreReceipt() {
        submitReceiptRestore(allowsReceiptRefresh: false, transaction: nil)
    }

    internal func submitReceiptRestore(allowsReceiptRefresh: Bool, transaction: SKPaymentTransaction?) {
        
        let receiptString = apphudReceiptDataString()
        
        if receiptString == nil && allowsReceiptRefresh {
            apphudLog("App Store receipt is missing on device, will refresh first then retry")
            ApphudStoreKitWrapper.shared.refreshReceipt(nil)
            return
        } else if receiptString == nil && transaction?.transactionIdentifier == nil && allowsReceiptRefresh == false {
            let error = ApphudError(message: "Failed to restore purchases because App Store receipt is missing on device.")
            apphudLog(error.localizedDescription, forceDisplay: true)
            self.restorePurchasesCallback?(self.currentUser?.subscriptions, self.currentUser?.purchases, error)
            self.restorePurchasesCallback = nil
            return
        } else if receiptString == nil && transaction?.transactionIdentifier != nil {
            apphudLog("App Store receipt is missing, but got transaction. Will try to submit transaction instead..", forceDisplay: true)
        }
        
        let exist = performWhenUserRegistered {

            self.submitReceipt(product: nil, apphudProduct: nil, transaction: transaction, receiptString: receiptString, notifyDelegate: true) { error in
                self.restorePurchasesCallback?(self.currentUser?.subscriptions, self.currentUser?.purchases, error)
                self.restorePurchasesCallback = nil
            }
        }
        if !exist {
            apphudLog("Tried to make restore allows: \(allowsReceiptRefresh) request when user is not yet registered, addind to schedule..")
        }
    }

    internal func submitReceipt(product: SKProduct, transaction: SKPaymentTransaction?, apphudProduct: ApphudProduct? = nil, callback: ((ApphudPurchaseResult) -> Void)?) {

        let block: (String?) -> Void = { receiptStr in
            if transaction != nil {
                self.submitReceipt(product: product, apphudProduct: apphudProduct, transaction: transaction, receiptString: receiptStr, notifyDelegate: true) { error in
                    let result = self.purchaseResult(productId: product.productIdentifier, transaction: transaction, error: error)
                    callback?(result)
                }
            } else {
                apphudLog("Tried to make submitReceipt: \(product.productIdentifier) request but transaction doesn't exist, addind to schedule..")
            }
        }

        if let receiptString = apphudReceiptDataString() {
            block(receiptString)
        } else {
            apphudLog("Receipt not found on device, refreshing.", forceDisplay: true)
            ApphudStoreKitWrapper.shared.refreshReceipt {
                if let receipt = apphudReceiptDataString() {
                    block(receipt)
                } else {
                    if transaction?.transactionIdentifier != nil {
                        apphudLog("App Store receipt is missing, but got transaction. Will try to submit transaction instead..", forceDisplay: true)
                        block(nil)
                    } else {
                        let message = "Failed to get App Store receipt"
                        apphudLog(message, forceDisplay: true)
                        callback?(ApphudPurchaseResult(nil, nil, transaction, ApphudError(message: "Failed to get App Store receipt")))
                    }
                }
            }
        }
    }
    
    internal func submitReceipt(product: SKProduct?, apphudProduct: ApphudProduct?, transaction: SKPaymentTransaction?, receiptString: String?, notifyDelegate: Bool, eligibilityCheck: Bool = false, callback: ApphudErrorCallback?) {
        self.submitReceipt(product: product,
                           apphudProduct: apphudProduct,
                           transactionIdentifier: transaction?.transactionIdentifier,
                           transactionProductIdentifier: transaction?.payment.productIdentifier,
                           transactionState: transaction?.transactionState,
                           receiptString: receiptString,
                           notifyDelegate: eligibilityCheck,
                           callback: callback)
    }
    
    internal func submitReceipt(product: SKProduct?,
                                apphudProduct: ApphudProduct?,
                                transactionIdentifier: String?,
                                transactionProductIdentifier: String?,
                                transactionState: SKPaymentTransactionState?,
                                receiptString: String?,
                                notifyDelegate: Bool,
                                eligibilityCheck: Bool = false,
                                callback: ApphudErrorCallback?) {

        if callback != nil {
            if eligibilityCheck || self.submitReceiptCallbacks.count > 0 {
                self.submitReceiptCallbacks.append(callback)
            } else {
                self.submitReceiptCallbacks = [callback]
            }
        }

        if isSubmittingReceipt {return}
        isSubmittingReceipt = true

        let environment = Apphud.isSandbox() ? "sandbox" : "production"

        var params: [String: Any] = ["device_id": self.currentDeviceID,
                                     "environment": environment,
                                     "observer_mode": ApphudUtils.shared.storeKitObserverMode]

        if let receipt = receiptString {
            params["receipt_data"] = receipt
        }
        if let transactionID = transactionIdentifier {
            params["transaction_id"] = transactionID
        }
        if let bundleID = Bundle.main.bundleIdentifier {
            params["bundle_id"] = bundleID
        }
        
        params["user_id"] = Apphud.userID()

        if let product = product {
            params["product_info"] = product.apphudSubmittableParameters()
        } else if let productID = transactionProductIdentifier, let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == productID}) {
            params["product_info"] = product.apphudSubmittableParameters()
        }

        if !eligibilityCheck {
            let mainProductID: String? = product?.productIdentifier ?? transactionProductIdentifier
            let other_products = ApphudStoreKitWrapper.shared.products.filter { $0.productIdentifier != mainProductID }
            params["other_products_info"] = other_products.map { $0.apphudSubmittableParameters() }
        }

        apphudProduct?.id.map { params["product_bundle_id"] = $0 }
        params["paywall_id"] = apphudProduct?.paywallId
        
        let hasMadePurchase = transactionState == .purchased
        
        if hasMadePurchase && params["paywall_id"] == nil && observerModePurchasePaywallIdentifier != nil {
            let paywall = paywalls.first(where: {$0.identifier == observerModePurchasePaywallIdentifier})
            params["paywall_id"] = paywall?.id
            let apphudP = paywall?.products.first(where: { $0.productId == transactionProductIdentifier })
            apphudP?.id.map { params["product_bundle_id"] = $0 }
        }
        
        #if os(iOS)
            if hasMadePurchase {
                ApphudRulesManager.shared.cacheActiveScreens()
            }
        #endif

        self.requiresReceiptSubmission = true

        apphudLog("Uploading App Store Receipt...")

        httpClient?.startRequest(path: .subscriptions, params: params, method: .post) { (result, response, _, error, errorCode, duration) in
            if error == nil && hasMadePurchase {
                ApphudLoggerService.shared.add(key: .subscriptions, value: duration, retryLog: self.submitReceiptRetries)
            }

            self.forceSendAttributionDataIfNeeded()
            self.isSubmittingReceipt = false
            
            if result {
                self.submitReceiptRetries = (0, 0)
                self.requiresReceiptSubmission = false
                let hasChanges = self.parseUser(response)
                if notifyDelegate {
                    if hasChanges.hasSubscriptionChanges {
                        self.delegate?.apphudSubscriptionsUpdated?(self.currentUser!.subscriptions)
                    }
                    if hasChanges.hasNonRenewingChanges {
                        self.delegate?.apphudNonRenewingPurchasesUpdated?(self.currentUser!.purchases)
                    }
                }
            } else {
                self.scheduleSubmitReceiptRetry(error: error, code: errorCode)
            }

            self.submitReceiptCallbacks.forEach { callback in callback?(error)}
            self.submitReceiptCallbacks.removeAll()
        }
    }

    internal func scheduleSubmitReceiptRetry(error: Error?, code: Int) {
        guard httpClient != nil, httpClient!.canRetry else {
            return
        }
        
        submitReceiptRetries.count += 1
        submitReceiptRetries.errorCode = code
        
        let delay: TimeInterval = TimeInterval(submitReceiptRetries.count)
        perform(#selector(submitAppStoreReceipt), with: nil, afterDelay: delay)
        apphudLog("Failed to upload App Store Receipt with error: \(error?.localizedDescription ?? "null"). Will retry in \(Int(delay)) seconds.", forceDisplay: true)
    }

    // MARK: - Internal purchase methods

    internal func purchase(productId: String, product: ApphudProduct?, validate: Bool, callback: ((ApphudPurchaseResult) -> Void)?) {
        if let apphudProduct = product, let skProduct = apphudProduct.skProduct {
            purchase(product: skProduct, apphudProduct: apphudProduct, validate: validate, callback: callback)
        } else {
            if let apphudProduct = ApphudInternal.shared.allAvailableProducts.first(where: { $0.productId == productId }), let skProduct = apphudProduct.skProduct {
                purchase(product: skProduct, apphudProduct: apphudProduct, validate: validate, callback: callback)
            } else {
                apphudLog("Product with id \(productId) not found, re-fetching from App Store...")
                ApphudStoreKitWrapper.shared.fetchProduct(productId: productId) { product in
                    if let product = product {
                        self.purchase(product: product, apphudProduct: nil, validate: validate, callback: callback)
                    } else {
                        let message = "Unable to start payment because product identifier is invalid: [\([productId])]"
                        apphudLog(message, forceDisplay: true)
                        let result = ApphudPurchaseResult(nil, nil, nil, ApphudError(message: message))
                        callback?(result)
                    }
                }
            }
        }
    }

    @available(iOS 12.2, *)
    internal func purchasePromo(skProduct: SKProduct, apphudProduct: ApphudProduct?, discountID: String, callback: ((ApphudPurchaseResult) -> Void)?) {

        self.signPromoOffer(productID: skProduct.productIdentifier, discountID: discountID) { (paymentDiscount, _) in
            if let paymentDiscount = paymentDiscount {
                self.purchasePromo(skProduct: skProduct, product: apphudProduct, discount: paymentDiscount, callback: callback)
            } else {
                callback?(ApphudPurchaseResult(nil, nil, nil, ApphudError(message: "Could not sign offer id: \(discountID), product id: \(skProduct.productIdentifier)")))
            }
        }
    }

    // MARK: - Private purchase methods

    private func purchase(product: SKProduct, apphudProduct: ApphudProduct?, validate: Bool, callback: ((ApphudPurchaseResult) -> Void)?) {
        ApphudLoggerService.shared.paywallCheckoutInitiated(apphudProduct?.paywallId, product.productIdentifier)
        ApphudStoreKitWrapper.shared.purchase(product: product) { transaction, error in
            if let error = error as? SKError {
                ApphudLoggerService.shared.paywallPaymentCancelled(apphudProduct?.paywallId, product.productIdentifier, error)
            }
            if validate {
                self.handleTransaction(product: product, transaction: transaction, error: error, apphudProduct: apphudProduct, callback: callback)
            } else {
                self.handleTransaction(product: product, transaction: transaction, error: error, apphudProduct: apphudProduct, callback: nil)
                callback?(ApphudPurchaseResult(nil, nil, transaction, error))
            }
        }
    }

    @available(iOS 12.2, *)
    private func purchasePromo(skProduct: SKProduct, product: ApphudProduct?, discount: SKPaymentDiscount, callback: ((ApphudPurchaseResult) -> Void)?) {

        ApphudStoreKitWrapper.shared.purchase(product: skProduct, discount: discount) { transaction, error in
            if let error = error as? SKError {
                ApphudLoggerService.shared.paywallPaymentCancelled(product?.paywallId, skProduct.productIdentifier, error)
            }
            self.handleTransaction(product: skProduct, transaction: transaction, error: error, apphudProduct: product, callback: callback)
        }
    }
    
    internal func willPurchaseProductFromPaywall(identifier: String?)  {
        observerModePurchasePaywallIdentifier = identifier
    }

    private func handleTransaction(product: SKProduct, transaction: SKPaymentTransaction, error: Error?, apphudProduct: ApphudProduct?, callback: ((ApphudPurchaseResult) -> Void)?) {
        if transaction.transactionState == .purchased || transaction.failedWithUnknownReason {
            self.submitReceipt(product: product, transaction: transaction, apphudProduct: apphudProduct) { [self] (result) in
                ApphudStoreKitWrapper.shared.finishTransaction(transaction)
                callback?(result)
            }
        } else {
            callback?(purchaseResult(productId: product.productIdentifier, transaction: transaction, error: error))
            ApphudStoreKitWrapper.shared.finishTransaction(transaction)
        }
    }

    private func purchaseResult(productId: String, transaction: SKPaymentTransaction?, error: Error?) -> ApphudPurchaseResult {

        // 1. try to find in app purchase by product id
        var purchase: ApphudNonRenewingPurchase?
        if transaction?.transactionState == .purchased {
            purchase = currentUser?.purchases.first(where: {$0.productId == productId})
        }

        // 1. try to find subscription by product id
        var subscription = currentUser?.subscriptions.first(where: {$0.productId == productId})
        // 2. try to find subscription by SKProduct's subscriptionGroupIdentifier
        if purchase == nil, subscription == nil, #available(iOS 12.2, *) {
            let targetProduct = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == productId})
            for sub in currentUser?.subscriptions ?? [] {
                if let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == sub.productId}),
                targetProduct?.subscriptionGroupIdentifier == product.subscriptionGroupIdentifier {
                    subscription = sub
                    break
                }
            }
        }

        // 3. Try to find subscription by Apphud Product Group ID
        if subscription == nil, let groupID = self.groupID(productId: productId) {
            subscription = currentUser?.subscriptions.first(where: { self.groupID(productId: $0.productId) == groupID})
        }

        return ApphudPurchaseResult(subscription, purchase, transaction, error ?? transaction?.error)
    }

    @available(iOS 12.2, *)
    private func signPromoOffer(productID: String, discountID: String, callback: ((SKPaymentDiscount?, Error?) -> Void)?) {
        let params: [String: Any] = ["product_id": productID, "offer_id": discountID, "application_username": ApphudStoreKitWrapper.shared.appropriateApplicationUsername() ?? "", "device_id": currentDeviceID, "user_id": currentUserID ]
        httpClient?.startRequest(path: .signOffer, params: params, method: .post) { (result, dict, _, error, _, _) in
            if result, let responseDict = dict, let dataDict = responseDict["data"] as? [String: Any], let resultsDict = dataDict["results"] as? [String: Any] {

                let signatureData = resultsDict["data"] as? [String: Any]
                let uuid = UUID(uuidString: signatureData?["nonce"] as? String ?? "")
                let signature = signatureData?["signature"] as? String
                let timestamp = signatureData?["timestamp"] as? NSNumber
                let keyID = resultsDict["key_id"] as? String

                if signature != nil && uuid != nil && timestamp != nil && keyID != nil {
                    let paymentDiscount = SKPaymentDiscount(identifier: discountID, keyIdentifier: keyID!, nonce: uuid!, signature: signature!, timestamp: timestamp!)
                    callback?(paymentDiscount, nil)
                    return
                }
            }

            let error = ApphudError(message: "Could not sign promo offer id: \(discountID), product id: \(productID)")
            callback?(nil, error)
        }
    }
}
