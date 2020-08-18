//
//  ApphudInternal+Purchase.swift
//  apphud
//
//  Created by Renat on 01.07.2020.
//  Copyright © 2020 softeam. All rights reserved.
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
            self.submitReceipt(product: nil, transaction: transaction, receiptString: receiptString, notifyDelegate: true, callback: nil)
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
            self.submitReceipt(product: nil, transaction: nil, receiptString: receiptString, notifyDelegate: true) { error in
                self.restorePurchasesCallback?(self.currentUser?.subscriptions, self.currentUser?.purchases, error)
                self.restorePurchasesCallback = nil
            }
        }
        if !exist {
            apphudLog("Tried to make restore allows: \(allowsReceiptRefresh) request when user is not yet registered, addind to schedule..")
        }
    }

    internal func submitReceipt(product: SKProduct, transaction: SKPaymentTransaction?, callback: ((ApphudPurchaseResult) -> Void)?) {

        let block: (String) -> Void = { receiptStr in
            let exist = self.performWhenUserRegistered {
                self.submitReceipt(product: product, transaction: transaction, receiptString: receiptStr, notifyDelegate: true) { error in
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
                    apphudLog("Failed to get App Store receipt", forceDisplay: true)
                    callback?(ApphudPurchaseResult(nil, nil, transaction, ApphudError(message: "Failed to get App Store receipt")))
                }
            }
        }
    }

    internal func submitReceipt(product: SKProduct?, transaction: SKPaymentTransaction?, receiptString: String, notifyDelegate: Bool, callback: ((Error?) -> Void)?) {

        if callback != nil {
            self.submitReceiptCallback = callback
        }

        if isSubmittingReceipt {return}
        isSubmittingReceipt = true

        let environment = Apphud.isSandbox() ? "sandbox" : "production"

        var params: [String: Any] = ["device_id": self.currentDeviceID,
                                          "receipt_data": receiptString,
                                          "environment": environment]

        if let transactionID = transaction?.transactionIdentifier {
            params["transaction_id"] = transactionID
        }
        if let product = product {
            params["product_info"] = product.apphudSubmittableParameters()
        } else if let productID = transaction?.payment.productIdentifier, let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == productID}) {
            params["product_info"] = product.apphudSubmittableParameters()
        }

        self.requiresReceiptSubmission = true

        apphudLog("Uploading App Store Receipt...")

        httpClient.startRequest(path: "subscriptions", params: params, method: .post) { (result, response, error, code) in
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
            submitReceiptRetriesCount += 1
            let delay: TimeInterval = TimeInterval(submitReceiptRetriesCount * 5)
            perform(#selector(submitAppStoreReceipt), with: nil, afterDelay: delay)
            apphudLog("Failed to upload App Store Receipt, will retry in \(delay) seconds.", forceDisplay: true)
        }

        self.submitReceiptCallback?(error)
        self.submitReceiptCallback = nil
    }

    internal func purchase(product: SKProduct, callback: ((ApphudPurchaseResult) -> Void)?) {
        ApphudStoreKitWrapper.shared.purchase(product: product) { transaction, error in
            self.handleTransaction(product: product, transaction: transaction, error: error) { (result) in
                callback?(result)
            }
        }
    }

    internal func purchaseWithoutValidation(product: SKProduct, callback: ApphudTransactionCallback?) {
        ApphudStoreKitWrapper.shared.purchase(product: product) { transaction, error in
            self.handleTransaction(product: product, transaction: transaction, error: error, callback: nil)
            callback?(transaction, error)
        }
    }

    @available(iOS 12.2, *)
    internal func purchasePromo(product: SKProduct, discountID: String, callback: ((ApphudPurchaseResult) -> Void)?) {
        self.signPromoOffer(productID: product.productIdentifier, discountID: discountID) { (paymentDiscount, _) in
            if let paymentDiscount = paymentDiscount {
                self.purchasePromo(product: product, discount: paymentDiscount, callback: callback)
            } else {
                callback?(ApphudPurchaseResult(nil, nil, nil, ApphudError(message: "Could not sign offer id: \(discountID), product id: \(product.productIdentifier)")))
            }
        }
    }

    @available(iOS 12.2, *)
    internal func purchasePromo(product: SKProduct, discount: SKPaymentDiscount, callback: ((ApphudPurchaseResult) -> Void)?) {
        ApphudStoreKitWrapper.shared.purchase(product: product, discount: discount) { transaction, error in
            self.handleTransaction(product: product, transaction: transaction, error: error, callback: callback)
        }
    }

    private func handleTransaction(product: SKProduct, transaction: SKPaymentTransaction, error: Error?, callback: ((ApphudPurchaseResult) -> Void)?) {
        if transaction.transactionState == .purchased || transaction.failedWithUnknownReason {
            self.submitReceipt(product: product, transaction: transaction) { (result) in
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

        // 3. Try to find subscription by groupID provided in Apphud project settings
        if subscription == nil, let groupID = self.productsGroupsMap?[productId] {
            subscription = currentUser?.subscriptions.first(where: { self.productsGroupsMap?[$0.productId] == groupID})
        }

        return ApphudPurchaseResult(subscription, purchase, transaction, error ?? transaction?.error)
    }

    @available(iOS 12.2, *)
    internal func signPromoOffer(productID: String, discountID: String, callback: ((SKPaymentDiscount?, Error?) -> Void)?) {
        let params: [String: Any] = ["product_id": productID, "offer_id": discountID ]
        httpClient.startRequest(path: "sign_offer", params: params, method: .post) { (result, dict, error, _) in
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
