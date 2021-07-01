//
//  ApphudInternal+Purchase.swift
//  apphud
//
//  Created by Renat on 01.07.2020.
//  Copyright © 2020 Apphud Inc. All rights reserved.
//

import Foundation
import StoreKit

extension ApphudInternal {

    // MARK: - Main Purchase and Submit Receipt methods

    internal func restorePurchases(callback: @escaping ([ApphudSubscription]?, [ApphudNonRenewingPurchase]?, Error?) -> Void) {
        self.restorePurchasesCallback = callback
        self.submitReceiptRestore(allowsReceiptRefresh: true)
    }

    internal func submitReceiptAutomaticPurchaseTracking(transaction: SKPaymentTransaction) {

        if isSubmittingReceipt {return}

        performWhenUserRegistered {
            guard let receiptString = apphudReceiptDataString() else { return }
            self.submitReceipt(product: nil, apphudProduct: nil, transaction: transaction, receiptString: receiptString, notifyDelegate: true, callback: nil)
        }
    }

    @objc internal func submitAppStoreReceipt() {
        submitReceiptRestore(allowsReceiptRefresh: false)
    }

    internal func submitReceiptRestore(allowsReceiptRefresh: Bool) {
        guard let receiptString = apphudReceiptDataString() else {
            if allowsReceiptRefresh {
                apphudLog("App Store receipt is missing on device, will refresh first then retry")
                ApphudStoreKitWrapper.shared.refreshReceipt(nil)
            } else {
                apphudLog("App Store receipt is missing on device and couldn't be refreshed.", forceDisplay: true)
                self.restorePurchasesCallback?(nil, nil, nil)
                self.restorePurchasesCallback = nil
            }
            return
        }

        let exist = performWhenUserRegistered {
            
            self.submitReceipt(product: nil, apphudProduct: nil, transaction: nil, receiptString: receiptString, notifyDelegate: true) { error in
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
            let exist = self.performWhenUserRegistered {
                self.submitReceipt(product: product, apphudProduct: apphudProduct, transaction: transaction, receiptString: receiptStr, notifyDelegate: true) { error in
                    let result = self.purchaseResult(productId: product.productIdentifier, transaction: transaction, error: error)
                    callback?(result)
                }
            }
            if !exist {
                apphudLog("Tried to make submitReceipt: \(product.productIdentifier) request when user is not yet registered, addind to schedule..")
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
                    if let transactionOid = transaction?.transactionIdentifier {
                        ApphudLoggerService.logError("Receipt not found, submit receipt with transactionIdentifier \(transactionOid)")
                        block(nil)
                    } else {
                        let message = "Failed to get App Store receipt"
                        ApphudLoggerService.logError(message)
                        apphudLog(message, forceDisplay: true)
                        callback?(ApphudPurchaseResult(nil, nil, transaction, ApphudError(message: "Failed to get App Store receipt")))
                    }
                }
            }
        }
    }

    internal func submitReceipt(product: SKProduct?, apphudProduct: ApphudProduct?, transaction: SKPaymentTransaction?, receiptString: String?, notifyDelegate: Bool, eligibilityCheck: Bool = false, callback: ApphudErrorCallback?) {

        if callback != nil {
            if eligibilityCheck {
                self.submitReceiptCallbacks.append(callback)
            } else {
                self.submitReceiptCallbacks = [callback]
            }
        }

        if isSubmittingReceipt {return}
        isSubmittingReceipt = true

        let environment = Apphud.isSandbox() ? "sandbox" : "production"

        var params: [String: Any] = ["device_id": self.currentDeviceID,
                                          "environment": environment]
        
        if let receipt = receiptString {
            params["receipt_data"] = receipt
        }
        if let transactionID = transaction?.transactionIdentifier {
            params["transaction_id"] = transactionID
        }
        if let bundleID = Bundle.main.bundleIdentifier {
            params["bundle_id"] = bundleID
        }
        
        if let product = product {
            params["product_info"] = product.apphudSubmittableParameters()
        } else if let productID = transaction?.payment.productIdentifier, let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == productID}) {
            params["product_info"] = product.apphudSubmittableParameters()
        }
        
        if !eligibilityCheck {
            let mainProductID: String? = product?.productIdentifier ?? transaction?.payment.productIdentifier
            let other_products = ApphudStoreKitWrapper.shared.products.filter { $0.productIdentifier != mainProductID }
            params["other_products_info"] = other_products.map { $0.apphudSubmittableParameters() }
        }
        
        apphudProduct?.id.map { params["product_bundle_id"] = $0 }
        apphudProduct?.paywallId.map { params["paywall_id"] = $0 }
        
        if transaction?.transactionState == .purchased {
            ApphudRulesManager.shared.cacheActiveScreens()
        }

        self.requiresReceiptSubmission = true

        apphudLog("Uploading App Store Receipt...")

        httpClient?.startRequest(path: "subscriptions", params: params, method: .post) { (result, response, _, error, _) in
            self.forceSendAttributionDataIfNeeded()
            self.isSubmittingReceipt = false
            self.handleSubmitReceiptCallback(result: result, response: response, error: error, notifyDelegate: notifyDelegate)
        }
    }

    internal func handleSubmitReceiptCallback(result: Bool, response: [String: Any]?, error: Error?, notifyDelegate: Bool) {

        if result {
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
            scheduleSubmitReceiptRetry(error: error)
        }

        self.submitReceiptCallbacks.forEach { callback in callback?(error)}
        self.submitReceiptCallbacks.removeAll()
    }
    
    internal func scheduleSubmitReceiptRetry(error: Error?) {
        guard httpClient != nil, httpClient!.canRetry else {
            return
        }
        submitReceiptRetriesCount += 1
        let delay: TimeInterval = TimeInterval(submitReceiptRetriesCount * 5)
        perform(#selector(submitAppStoreReceipt), with: nil, afterDelay: delay)
        apphudLog("Failed to upload App Store Receipt with error: \(error?.localizedDescription ?? "null"). Will retry in \(Int(delay)) seconds.", forceDisplay: true)
    }

    // MARK: - Internal purchase methods
    
    internal func purchase(productId: String, product:ApphudProduct?, validate: Bool, callback: ((ApphudPurchaseResult) -> Void)?) {
        if let apphudProduct = product, let skProduct = apphudProduct.skProduct {
            purchase(product: skProduct, apphudProduct: apphudProduct, validate:validate, callback: callback)
        } else {
            if let apphudProduct = ApphudInternal.shared.allAvailableProducts.first(where: { $0.productId == productId }), let skProduct = apphudProduct.skProduct {
                purchase(product: skProduct, apphudProduct: apphudProduct, validate:validate, callback: callback)
            } else {
                apphudLog("Product with id \(productId) not found, re-fetching from App Store...")
                ApphudStoreKitWrapper.shared.fetchProduct(productId: productId) { product in
                    if let product = product {
                        self.purchase(product: product, apphudProduct: nil, validate: validate, callback: callback)
                    } else {
                        let message = "Unable to start payment because product identifier is invalid: [\([productId])]"
                        ApphudLoggerService.logError(message)
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
        ApphudLoggerService.paywallCheckoutInitiated(apphudProduct?.paywallId, product.productIdentifier)
        ApphudStoreKitWrapper.shared.purchase(product: product) { transaction, error in
            if let error = error as? SKError {
                ApphudLoggerService.paywallPaymentCancelled(apphudProduct?.paywallId, product.productIdentifier, error)
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
            self.handleTransaction(product: skProduct, transaction: transaction, error: error, apphudProduct: product, callback: callback)
        }
    }

    private func handleTransaction(product: SKProduct, transaction: SKPaymentTransaction, error: Error?, apphudProduct: ApphudProduct?, callback: ((ApphudPurchaseResult) -> Void)?) {
        if transaction.transactionState == .purchased || transaction.failedWithUnknownReason {
            self.submitReceipt(product: product, transaction: transaction, apphudProduct: apphudProduct) { (result) in
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
        let params: [String: Any] = ["product_id": productID, "offer_id": discountID ]
        httpClient?.startRequest(path: "sign_offer", params: params, method: .post) { (result, dict, _, error, _) in
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
