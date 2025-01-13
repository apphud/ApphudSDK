//
//  ApphudInternal+Purchase.swift
//  apphud
//
//  Created by Renat on 01.07.2020.
//  Copyright © 2020 Apphud Inc. All rights reserved.
//

import Foundation
import StoreKit
import SwiftUI

extension ApphudInternal {

    // MARK: - Main Purchase and Submit Receipt methods

    @MainActor internal func migrateiOS14PurchasesIfNeeded() {
        if apphudShouldMigrate() {
            ApphudInternal.shared.restorePurchases { (subscriptions, purchases, error) in
                if error == nil {
                    apphudDidMigrate()
                }
            }
        }
    }
    
    @MainActor internal func restorePurchases(callback: @escaping ([ApphudSubscription]?, [ApphudNonRenewingPurchase]?, Error?) -> Void) {
        self.restorePurchasesCallback = { subs, purchases, error in
            if error != nil { ApphudStoreKitWrapper.shared.restoreTransactions() }
            callback(subs, purchases, error)
        }
        self.submitReceiptRestore(allowsReceiptRefresh: true, transaction: nil)
    }

    internal func setNeedToCheckTransactions() {
        apphudPerformOnMainThread {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.checkTransactionsNow), object: nil)
            self.perform(#selector(self.checkTransactionsNow), with: nil, afterDelay: 3)
        }
    }

    @MainActor @objc private func checkTransactionsNow() {

        if ApphudStoreKitWrapper.shared.isPurchasing {
            return
        }

        if #available(iOS 15.0, tvOS 15.0, watchOS 8.0, macOS 12.0, *) {

            if ApphudAsyncStoreKit.shared.isPurchasing { return }

            Task {
                for await result in StoreKit.Transaction.currentEntitlements {
                    if case .verified(let transaction) = result {
                        await handleTransaction(transaction)
                    }
                }
            }
        }
    }

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @discardableResult internal func handleTransaction(_ transaction: StoreKit.Transaction) async -> Bool {
        let transactionId = transaction.id
        let refundDate = transaction.revocationDate
        let expirationDate = transaction.expirationDate
        let purchaseDate = transaction.purchaseDate
        let upgrade = transaction.isUpgraded
        let productID = transaction.productID

        let transactions = await self.lastUploadedTransactions

        if transactions.contains(transactionId) {
            return false
        }

        var isActive = false
        switch transaction.productType {
        case .autoRenewable:
            isActive = expirationDate != nil && expirationDate! > Date() && refundDate == nil && upgrade == false
        default:
            isActive = purchaseDate > Date().addingTimeInterval(-86_400) && refundDate == nil
        }

        if isActive {
            apphudLog("found transaction with ID: \(transactionId), \(productID), purchase date: \(purchaseDate)", logLevel: .debug)
            if self.submittingTransaction == String(transactionId) {
                apphudLog("Already submitting the same transaction id \(transactionId), skipping", logLevel: .debug)
                return false
            }

            let product = await ApphudStoreKitWrapper.shared.fetchProduct(productID)
            try? await ApphudAsyncStoreKit.shared.fetchProductIfNeeded(productID)
            let receipt = await appStoreReceipt()
            let isRecentlyPurchased: Bool = purchaseDate > Date().addingTimeInterval(-600)
            return await withUnsafeContinuation { continuation in
                performWhenUserRegistered {
                    apphudLog("Submitting transaction \(transactionId), \(productID) from StoreKit2..")

                    var trx = self.lastUploadedTransactions
                    trx.append(transactionId)
                    self.lastUploadedTransactions = trx

                    Task {
                        await self.submitReceipt(product: product,
                                           apphudProduct: nil,
                                           transactionIdentifier: String(transactionId),
                                           transactionProductIdentifier: productID,
                                           transactionState: isRecentlyPurchased ? .purchased : nil,
                                           receiptString: receipt,
                                                 notifyDelegate: true) { _ in
                            continuation.resume(returning: true)
                        }
                    }
                }
            }
        }
        return false
    }

    internal func appStoreReceipt() async -> String? {
        if let receiptString = apphudReceiptDataString() {
            return receiptString
        }

        apphudLog("App Store receipt is missing on device, refreshing...")

        return await withUnsafeContinuation { continuation in
            ApphudStoreKitWrapper.shared.refreshReceipt {
                continuation.resume(returning: apphudReceiptDataString())
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
        Task { @MainActor in
            submitReceiptRestore(allowsReceiptRefresh: false, transaction: nil)
        }
    }

    @MainActor internal func submitReceiptRestore(allowsReceiptRefresh: Bool, transaction: SKPaymentTransaction?) {

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

        performWhenUserRegistered {

            self.submitReceipt(product: nil, apphudProduct: nil, transaction: transaction, receiptString: receiptString, notifyDelegate: true) { error in
                self.restorePurchasesCallback?(self.currentUser?.subscriptions, self.currentUser?.purchases, error)
                self.restorePurchasesCallback = nil
            }
        }
    }

    internal func submitReceipt(product: SKProduct, transaction: SKPaymentTransaction?, apphudProduct: ApphudProduct? = nil, callback: ((ApphudPurchaseResult) -> Void)?) {

        let block: (String?) -> Void = { receiptStr in
            if transaction != nil {
                self.submitReceipt(product: product, apphudProduct: apphudProduct, transaction: transaction, receiptString: receiptStr, notifyDelegate: true) { error in
                    Task { @MainActor in
                        let result = self.purchaseResult(productId: product.productIdentifier, transaction: transaction, error: error)
                        callback?(result)
                    }
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

    internal func submitReceipt(product: SKProduct?, apphudProduct: ApphudProduct?, transaction: SKPaymentTransaction?, receiptString: String?, notifyDelegate: Bool, eligibilityCheck: Bool = false, callback: ApphudNSErrorCallback?) {

        let productId = product?.productIdentifier ?? transaction?.payment.productIdentifier
        let finalProduct = product ?? ApphudStoreKitWrapper.shared.products.first(where: { $0.productIdentifier == productId })

        let block: ((SKProduct?) -> Void) = { pr in
            Task {
                await self.submitReceipt(product: pr,
                                   apphudProduct: apphudProduct,
                                   transactionIdentifier: transaction?.transactionIdentifier,
                                   transactionProductIdentifier: productId,
                                   transactionState: transaction?.transactionState,
                                   receiptString: receiptString,
                                   notifyDelegate: notifyDelegate,
                                   eligibilityCheck: eligibilityCheck,
                                   callback: callback)
            }
        }

        if finalProduct == nil && productId != nil {
            ApphudStoreKitWrapper.shared.fetchProducts(productIds: [productId!]) { prds in
                block(prds?.first(where: { $0.productIdentifier == productId! }))
            }
        } else {
            block(finalProduct)
        }
    }

    internal func submitReceipt(product: SKProduct?,
                                apphudProduct: ApphudProduct?,
                                transactionIdentifier: String?,
                                transactionProductIdentifier: String?,
                                transactionState: SKPaymentTransactionState?,
                                receiptString: String?,
                                notifyDelegate: Bool,
                                eligibilityCheck: Bool = false,
                                callback: ApphudNSErrorCallback?) async {

        await MainActor.run {
            if callback != nil {
                if eligibilityCheck || self.submitReceiptCallbacks.count > 0 {
                    self.submitReceiptCallbacks.append(callback)
                } else {
                    self.submitReceiptCallbacks = [callback]
                }
            }
        }

        if submittingTransaction != nil {
            apphudLog("Already submitting some receipt (\(submittingTransaction!)), exiting")
            return
        }
        submittingTransaction = transactionIdentifier ?? transactionProductIdentifier ?? product?.productIdentifier ?? "Restoration"

        let environment = Apphud.isSandbox() ? ApphudEnvironment.sandbox.rawValue : ApphudEnvironment.production.rawValue

        var params: [String: Any] = ["device_id": self.currentDeviceID,
                                     "environment": environment,
                                     "observer_mode": ApphudUtils.shared.storeKitObserverMode]

        if (!ApphudUtils.shared.useStoreKitV2 || transactionIdentifier == nil), let receipt = receiptString {
            params["receipt_data"] = receipt
        }

        if let transactionID = transactionIdentifier {
            params["transaction_id"] = transactionID
        }
        if let bundleID = Bundle.main.bundleIdentifier {
            params["bundle_id"] = bundleID
        }

        let hasMadePurchase = transactionState == .purchased

        params["user_id"] = currentUserID

        if let info = product?.apphudSubmittableParameters(hasMadePurchase) {
            params["product_info"] = info
        }

        if hasMadePurchase, let purchasedApphudProduct = apphudProduct ?? purchasingProduct, purchasedApphudProduct.productId == transactionProductIdentifier {
            params["product_bundle_id"] = purchasedApphudProduct.id
            params["paywall_id"] = purchasedApphudProduct.paywallId
            params["placement_id"] = purchasedApphudProduct.placementId
            if let varID = purchasedApphudProduct.variationIdentifier {
                params["variation_identifier"] = varID
            }
            if let expID = purchasedApphudProduct.experimentId {
                params["experiment_id"] = expID
            }
        }

        purchasingProduct = nil

        if hasMadePurchase && params["paywall_id"] == nil && observerModePurchaseIdentifiers?.paywall != nil {

            var paywall: ApphudPaywall?

            if observerModePurchaseIdentifiers?.placement != nil {
                let placement = await placements.first(where: { $0.identifier == observerModePurchaseIdentifiers?.placement })
                if params["placement_id"] == nil && placement != nil {
                    params["placement_id"] = placement?.id
                }
                paywall = placement?.paywalls.first
            } else {
                paywall = await paywalls.first(where: {$0.identifier == observerModePurchaseIdentifiers?.paywall})
            }

            params["paywall_id"] = paywall?.id
            if let varID = paywall?.variationIdentifier {
                params["variation_identifier"] = varID
            }
            if let expID = paywall?.experimentId {
                params["experiment_id"] = expID
            }
            
            let apphudP = paywall?.products.first(where: { $0.productId == transactionProductIdentifier })
            apphudP?.id.map { params["product_bundle_id"] = $0 }
        }

        #if os(iOS)
            if hasMadePurchase {
                Task { @MainActor in
                    ApphudRulesManager.shared.cacheActiveScreens()
                }
            }
        #endif
        
        let transactionId = params["transaction_id"] as? String
        await MainActor.run {
            if transactionId != nil, let trInt = UInt64(transactionId!) {
                var trx = self.lastUploadedTransactions
                trx.append(trInt)
                self.lastUploadedTransactions = trx
            }
        }
        
        self.requiresReceiptSubmission = true

        apphudLog("Uploading App Store Receipt...")

        httpClient?.startRequest(path: .subscriptions, params: params, method: .post, useDecoder: true, retry: (hasMadePurchase && !fallbackMode)) { (result, _, data, error, errorCode, duration, attempts) in
            Task { @MainActor in
                if !result && hasMadePurchase && self.fallbackMode {
                    self.requiresReceiptSubmission = true
                    self.submittingTransaction = nil
                    let hasChanges = self.stubPurchase(product: product ?? apphudProduct?.skProduct)
                    self.notifyAboutUpdates(hasChanges)
                    self.submitReceiptCallbacks.forEach { callback in callback?(error)}
                    self.submitReceiptCallbacks.removeAll()
                    return
                }

                if result && hasMadePurchase {
                    ApphudLoggerService.shared.add(key: .subscriptions, value: duration, retryLog: self.submitReceiptRetries)
                }

                if result && hasMadePurchase && Apphud.hasPremiumAccess() && self.fallbackMode {
                    apphudLog("disable fallback mode", logLevel: .all)
                    self.fallbackMode = false
                }

                self.forceSendAttributionDataIfNeeded()
                self.submittingTransaction = nil

                if result {
                    self.observerModePurchaseIdentifiers = nil
                    self.submitReceiptRetries = (0, 0)
                    self.requiresReceiptSubmission = false
                    let hasChanges = await self.parseUser(data: data)
                    if notifyDelegate {
                        self.notifyAboutUpdates(hasChanges)
                    }
                } else {
                    self.lastUploadedTransactions = []
                    self.scheduleSubmitReceiptRetry(error: error, code: errorCode)
                }
                
                while !self.submitReceiptCallbacks.isEmpty {
                    let callback = self.submitReceiptCallbacks.removeFirst()
                    callback?(error)
                }
            }
        }
    }

    @MainActor
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

    @MainActor
    @available(iOS 13.0.0, macOS 11.0, watchOS 6.0, tvOS 13.0, *)
    internal func purchase(productId: String, product: ApphudProduct?, validate: Bool, isPurchasing: Binding<Bool>? = nil, value: Double? = nil) async -> ApphudPurchaseResult {
        await withUnsafeContinuation { continuation in
            isPurchasing?.wrappedValue = true
            purchase(productId: productId, product: product, validate: validate, callback: { result in
                isPurchasing?.wrappedValue = false
                continuation.resume(returning: result)
            })
        }
    }

    @MainActor internal func purchase(productId: String, product: ApphudProduct?, validate: Bool, value: Double? = nil, callback: ((ApphudPurchaseResult) -> Void)?) {
        
        let skProduct = product?.skProduct ?? ApphudStoreKitWrapper.shared.products.first(where: { $0.productIdentifier == productId })
        
        if let skProduct = skProduct {
            purchase(product: skProduct, apphudProduct: product, validate: validate, value: value, callback: callback)
        } else {
            apphudLog("Product with id \(productId) not found, re-fetching from App Store...")
            ApphudStoreKitWrapper.shared.fetchProducts(productIds: [productId]) { prds in
                if let sk = prds?.first(where: { $0.productIdentifier == productId }) {
                    self.purchase(product: sk, apphudProduct: product, validate: validate, value: value, callback: callback)
                } else {
                    let message = "Unable to start payment because product identifier is invalid: [\([productId])]"
                    apphudLog(message, forceDisplay: true)
                    let result = ApphudPurchaseResult(nil, nil, nil, ApphudError(message: message))
                    callback?(result)
                }
            }
        }
    }

    internal func purchasePromo(skProduct: SKProduct?, apphudProduct: ApphudProduct?, discountID: String, callback: ((ApphudPurchaseResult) -> Void)?) {

        let skCallback: ((SKProduct) -> Void) = { skProduct in
            self.signPromoOffer(productID: skProduct.productIdentifier, discountID: discountID) { (paymentDiscount, _) in
                if let paymentDiscount = paymentDiscount {
                    self.purchasePromo(skProduct: skProduct, product: apphudProduct, discount: paymentDiscount, callback: callback)
                } else {
                    callback?(ApphudPurchaseResult(nil, nil, nil, ApphudError(message: "Could not sign offer id: \(discountID), product id: \(skProduct.productIdentifier)")))
                }
            }

        }

        if let skProduct = skProduct {
            skCallback(skProduct)
        } else if let productId = apphudProduct?.productId {
            Task {
                if let skProduct = await ApphudStoreKitWrapper.shared.fetchProduct(productId) {
                    apphudPerformOnMainThread {
                        skCallback(skProduct)
                    }
                }
            }
        }
    }

    // MARK: - Private purchase methods

    private func purchase(product: SKProduct, apphudProduct: ApphudProduct?, validate: Bool, value: Double? = nil, callback: ((ApphudPurchaseResult) -> Void)?) {
        ApphudLoggerService.shared.paywallCheckoutInitiated(apphudProduct: apphudProduct, productId: product.productIdentifier)

        purchasingProduct = apphudProduct

        ApphudStoreKitWrapper.shared.purchase(product: product, value: value) { transaction, error in

            if let error = error {
                ApphudLoggerService.shared.paywallPaymentError(paywallId: apphudProduct?.paywallId, placementId: apphudProduct?.placementId, productId: product.productIdentifier, error: error.apphudErrorMessage())
            }

            Task { @MainActor in
                if validate {
                    self.handleTransaction(product: product, transaction: transaction, error: error, apphudProduct: apphudProduct, callback: callback)
                } else {
                    self.handleTransaction(product: product, transaction: transaction, error: error, apphudProduct: apphudProduct, callback: nil)
                    callback?(ApphudPurchaseResult(nil, nil, transaction, error))
                }
            }
        }
    }

    private func purchasePromo(skProduct: SKProduct, product: ApphudProduct?, discount: SKPaymentDiscount, callback: ((ApphudPurchaseResult) -> Void)?) {

        purchasingProduct = product

        ApphudStoreKitWrapper.shared.purchase(product: skProduct, discount: discount) { transaction, error in
            if let error = error {
                ApphudLoggerService.shared.paywallPaymentError(paywallId: product?.paywallId, placementId: product?.placementId, productId: skProduct.productIdentifier, error: error.apphudErrorMessage())
            }

            Task { @MainActor in
                self.handleTransaction(product: skProduct, transaction: transaction, error: error, apphudProduct: product, callback: callback)
            }
        }
    }

    internal func willPurchaseProductFrom(paywallId: String, placementId: String?) {
        observerModePurchaseIdentifiers = (paywallId, placementId)
    }

    @MainActor private func handleTransaction(product: SKProduct, transaction: SKPaymentTransaction, error: Error?, apphudProduct: ApphudProduct?, callback: ((ApphudPurchaseResult) -> Void)?) {
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

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor internal func asyncPurchaseResult(product: Product, transaction: StoreKit.Transaction?, error: Error?) -> ApphudAsyncPurchaseResult {

        // 1. try to find in app purchase by product id
        let purchase = currentUser?.purchases.first(where: {$0.productId == product.id})

        // 2. try to find subscription by product id
        var subscription = currentUser?.subscriptions.first(where: {$0.productId == product.id})
        // 3. try to find subscription by Product's subscription group id

        if purchase == nil, subscription == nil {
            for sub in currentUser?.subscriptions ?? [] {
                if let targetProduct = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == sub.productId}),
                   targetProduct.subscriptionGroupIdentifier == product.subscription?.subscriptionGroupID && product.subscription != nil {
                    subscription = sub
                    break
                }
            }
        }

        return ApphudAsyncPurchaseResult(subscription: subscription, nonRenewingPurchase: purchase, transaction: transaction, error: error)
    }

    @MainActor private func purchaseResult(productId: String, transaction: SKPaymentTransaction?, error: Error?) -> ApphudPurchaseResult {

        // 1. try to find in app purchase by product id
        var purchase: ApphudNonRenewingPurchase?
        if transaction?.transactionState == .purchased {
            purchase = currentUser?.purchases.first(where: {$0.productId == productId})
        }

        // 1. try to find subscription by product id
        var subscription = currentUser?.subscriptions.first(where: {$0.productId == productId})
        // 2. try to find subscription by SKProduct's subscriptionGroupIdentifier
        if purchase == nil, subscription == nil {
            let targetProduct = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == productId})
            for sub in currentUser?.subscriptions ?? [] {
                if let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == sub.productId}),
                targetProduct?.subscriptionGroupIdentifier == product.subscriptionGroupIdentifier {
                    subscription = sub
                    break
                }
            }
        }

        return ApphudPurchaseResult(subscription, purchase, transaction, error ?? transaction?.error)
    }

    private func signPromoOffer(productID: String, discountID: String, callback: ((SKPaymentDiscount?, Error?) -> Void)?) {
        let params: [String: Any] = ["product_id": productID, "offer_id": discountID, "application_username": ApphudStoreKitWrapper.shared.appropriateApplicationUsername() ?? "", "device_id": currentDeviceID, "user_id": currentUserID ]
        httpClient?.startRequest(path: .signOffer, params: params, method: .post) { (result, dict, _, error, _, _, _) in
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
