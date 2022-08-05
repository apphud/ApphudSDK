//
//  ApphudStoreKitFetcher.swift
//  subscriptionstest
//
//  Created by ren6 on 01/07/2019.
//  Copyright © 2019 apphud. All rights reserved.
//

import Foundation
import StoreKit

internal typealias ApphudStoreKitProductsCallback = ([SKProduct], Error?) -> Void
internal typealias ApphudTransactionCallback = (SKPaymentTransaction, Error?) -> Void

public let _ApphudWillFinishTransactionNotification = Notification.Name(rawValue: "ApphudWillFinishTransactionNotification")
public let _ApphudDidFinishTransactionNotification = Notification.Name(rawValue: "ApphudDidFinishTransactionNotification")

@available(OSX 10.14.4, *)
@available(iOS 11.2, *)
internal class ApphudStoreKitWrapper: NSObject, SKPaymentTransactionObserver, SKRequestDelegate {
    static var shared = ApphudStoreKitWrapper()

    internal var products = [SKProduct]()
    internal var didFetch: Bool = false

    fileprivate let fetcher = ApphudProductsFetcher()
    fileprivate let singleFetcher = ApphudProductsFetcher()

    private var refreshReceiptCallback: (() -> Void)?
    private var paymentCallback: ApphudTransactionCallback?
    
    var purchasingProductID: String?
    var isPurchasing: Bool = false

    private var refreshRequest: SKReceiptRefreshRequest?

    internal var productsLoadTime: TimeInterval = 0.0
    
    func setupObserver() {
        SKPaymentQueue.default().add(self)
    }
    
    func enableSwizzle() {
        SKPaymentQueue.doSwizzle()
    }
    
    func restoreTransactions() {
        DispatchQueue.main.async {
            SKPaymentQueue.default().restoreCompletedTransactions()
        }
    }

    func refreshReceipt(_ callback: (() -> Void)?) {
        refreshReceiptCallback = callback
        refreshRequest = SKReceiptRefreshRequest()
        refreshRequest?.delegate = self
        refreshRequest?.start()
    }

    func fetchProducts(identifiers: Set<String>, callback: @escaping ApphudStoreKitProductsCallback) {
        let start = Date()
        fetcher.fetchStoreKitProducts(identifiers: identifiers) { products, error in
            if products.count > 0 {
                self.productsLoadTime = Date().timeIntervalSince(start)
            }
            let existingIDS = self.products.map { $0.productIdentifier }
            let uniqueProducts = products.filter { !existingIDS.contains($0.productIdentifier) }
            self.products.append(contentsOf: uniqueProducts)
            self.didFetch = true
            callback(products, error)
        }
    }

    func fetchProduct(productId: String, callback: @escaping (SKProduct?) -> Void) {
        singleFetcher.fetchStoreKitProducts(identifiers: Set([productId])) { products, _ in
            callback(products.first(where: { $0.productIdentifier == productId }))
        }
    }

    func purchase(product: SKProduct, callback: @escaping ApphudTransactionCallback) {
        ApphudUtils.shared.storeKitObserverMode = false
        let payment = SKMutablePayment(product: product)
        purchase(payment: payment, callback: callback)
    }

    @available(iOS 12.2, *)
    func purchase(product: SKProduct, discount: SKPaymentDiscount, callback: @escaping ApphudTransactionCallback) {
        ApphudUtils.shared.storeKitObserverMode = false
        let payment = SKMutablePayment(product: product)
        payment.paymentDiscount = discount
        purchase(payment: payment, callback: callback)
    }

    func purchase(payment: SKPayment, callback: @escaping ApphudTransactionCallback) {
        finishCompletedTransactions(for: payment.productIdentifier)
        paymentCallback = callback
        purchasingProductID = payment.productIdentifier
        apphudLog("Starting payment for \(payment.productIdentifier), transactions in queue: \(SKPaymentQueue.default().transactions)")
        SKPaymentQueue.default().add(payment)
    }
    
    // MARK: - SKPaymentTransactionObserver

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        DispatchQueue.main.async {

            // order purchased state before any others
            let sortedTransactions = transactions.sorted { first, _ in
                first.transactionState == .purchased
            }

            for trx in sortedTransactions {
                switch trx.transactionState {
                case .purchasing:
                    self.isPurchasing = true
                    apphudLog("Payment is in purchasing state \(trx.payment.productIdentifier) for username: \(trx.payment.applicationUsername ?? "")")
                    
                    if self.purchasingProductID == nil && ApphudUtils.shared.storeKitObserverMode == false {
                        apphudLog("Seems like Observer Mode is False however purchase is not being made through Apphud SDK. Please make sure you set ObserverMode to True when initialising Apphud SDK. As for now, force enabling observer mode..", logLevel: .off)
                        ApphudUtils.shared.storeKitObserverMode = true
                    }
                case .purchased, .failed:
                    self.isPurchasing = false
                    self.handleTransactionIfStarted(trx)
                case .restored:
                    /*
                     Always handle restored transactions by sending App Store Receipt to Apphud.
                     Will not finish transaction, because we didn't start it. Developer should finish transaction manually.
                     */
                    self.isPurchasing = false
                    ApphudInternal.shared.submitReceiptRestore(allowsReceiptRefresh: true, transaction: trx.original ?? trx)
                    if !ApphudUtils.shared.storeKitObserverMode {
                        // force finish transaction
                        self.finishTransaction(trx)
                    }
                case .deferred:
                    self.isPurchasing = false
                    self.handleDeferredTransaction(trx)
                default:
                    self.isPurchasing = false
                    break
                }
            }
        }
    }
    
    func handleDeferredTransaction(_ transaction: SKPaymentTransaction) {
        if let error = transaction.error as? SKError, error.code != .paymentCancelled {
            ApphudInternal.shared.delegate?.handleDeferredTransaction?(transaction: transaction)
        }
    }

    private func handleTransactionIfStarted(_ transaction: SKPaymentTransaction) {

        if transaction.payment.productIdentifier == self.purchasingProductID {
            if self.paymentCallback != nil {
                self.paymentCallback?(transaction, transaction.error)
            } else {
                finishTransaction(transaction)
            }
            self.paymentCallback = nil
        } else {
            if transaction.transactionState == .purchased {
                ApphudInternal.shared.submitReceiptAutomaticPurchaseTracking(transaction: transaction) { result in
                    if let finish = ApphudInternal.shared.delegate?.apphudDidObservePurchase?(result: result), finish == true {
                        self.finishTransaction(transaction)
                    }
                }
            } else if transaction.failedWithUnknownReason {
                ApphudInternal.shared.setNeedToCheckTransactions()
            }
        }
    }

    private func finishCompletedTransactions(for productIdentifier: String) {
        SKPaymentQueue.default().transactions
            .filter { $0.payment.productIdentifier == productIdentifier && $0.finishable }
            .forEach { transaction in finishTransaction(transaction) }
    }

    internal func finishTransaction(_ transaction: SKPaymentTransaction) {
        apphudLog("Finish Transaction: \(transaction.payment.productIdentifier), state: \(transaction.transactionState.rawValue), id: \(transaction.transactionIdentifier ?? "")")
        NotificationCenter.default.post(name: _ApphudWillFinishTransactionNotification, object: transaction)
        SKPaymentQueue.default().finishTransaction(transaction)
        self.purchasingProductID = nil
    }

    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        DispatchQueue.main.async {
            transactions.forEach { transaction in
                NotificationCenter.default.post(name: _ApphudDidFinishTransactionNotification, object: transaction)
            }
        }
    }

    #if os(iOS) && !targetEnvironment(macCatalyst)
    func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {

        DispatchQueue.main.async {
            if let callback = ApphudInternal.shared.delegate?.apphudShouldStartAppStoreDirectPurchase?(product) {
                ApphudInternal.shared.purchase(productId: product.productIdentifier, product: nil, validate: true, callback: callback)
            }
        }

        return false
    }
    #endif

    // MARK: - SKRequestDelegate

    func requestDidFinish(_ request: SKRequest) {
        if request is SKReceiptRefreshRequest {
            DispatchQueue.main.async {
                if self.refreshReceiptCallback != nil {
                    self.refreshReceiptCallback?()
                    self.refreshReceiptCallback = nil
                } else {
                    ApphudInternal.shared.submitReceiptRestore(allowsReceiptRefresh: false, transaction: nil)
                }
                self.refreshRequest = nil
            }
        }
    }

    /**
     Try to restore even if refresh receipt failed. Current receipt (unrefreshed) will be sent instead.
     */
    func request(_ request: SKRequest, didFailWithError error: Error) {
        if request is SKReceiptRefreshRequest {
            DispatchQueue.main.async {
                if self.refreshReceiptCallback != nil {
                    self.refreshReceiptCallback?()
                    self.refreshReceiptCallback = nil
                } else {
                    ApphudInternal.shared.submitReceiptRestore(allowsReceiptRefresh: false, transaction: nil)
                }
                self.refreshRequest = nil
            }
        }
    }

    func presentOfferCodeSheet() {
        if #available(iOS 14.0, *) {
            #if os(iOS)
            SKPaymentQueue.default().presentCodeRedemptionSheet()
            #endif
        } else {
            apphudLog("Method unavailable on current iOS version (minimum 14.0).", forceDisplay: true)
        }
    }
    
    internal func appropriateApplicationUsername() -> String? {
        if !hasSwizzledPaymentQueue { return nil }
        let userID = ApphudInternal.shared.currentUserID
        let userIDIsUUID = UUID(uuidString: userID)
        let betterUUID = (userIDIsUUID != nil) ? userID : ApphudInternal.shared.currentDeviceID
        return betterUUID
    }
}

/*
 This class will be extended in the future.
 */
@available(OSX 10.14.4, *)
private class ApphudProductsFetcher: NSObject, SKProductsRequestDelegate {
    private var callback: ApphudStoreKitProductsCallback?

    private var productsRequest: SKProductsRequest?

    func fetchStoreKitProducts(identifiers: Set<String>, callback : @escaping ApphudStoreKitProductsCallback) {
        self.callback = callback
        productsRequest?.delegate = nil
        productsRequest?.cancel()
        productsRequest = SKProductsRequest(productIdentifiers: identifiers)
        productsRequest?.delegate = self
        productsRequest?.start()
    }

    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.callback?(response.products, nil)
            if response.invalidProductIdentifiers.count > 0 {
                apphudLog("Failed to load SKProducts from the App Store, because product identifiers are invalid:\n \(response.invalidProductIdentifiers)\n\tFor more details visit: https://docs.apphud.com/testing/ios#failed-to-load-skproducts-from-the-app-store-error", forceDisplay: true)
            }
            if response.products.count > 0 {
                apphudLog("Successfully fetched SKProducts from the App Store:\n \(response.products.map { $0.productIdentifier })")
            }
            self.callback = nil
            self.productsRequest = nil
        }
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async {
            if (error as NSError).description.contains("Attempted to decode store response") {
                apphudLog("Failed to load SKProducts from the App Store, error: \(error). [!] App Store features in iOS Simulator are not supported. For more details visit: https://docs.apphud.com/testing/ios#attempted-to-decode-store-response-error-while-fetching-products", forceDisplay: true)
            } else {
                apphudLog("Failed to load SKProducts from the App Store, error: \(error)", forceDisplay: true)
            }

            self.callback?([], error)
            self.callback = nil
            self.productsRequest = nil
        }
    }
}

extension SKPaymentTransaction {
    var failedWithUnknownReason: Bool {
        transactionState == .failed && (error is SKError) && (error as? SKError)?.code == SKError.Code.unknown
    }

    var finishable: Bool {
        switch transactionState {
        case .purchasing:
            return false
        case .deferred, .failed, .purchased, .restored:
            return true
        @unknown default:
            return false
        }
    }
}

private var hasSwizzledPaymentQueue = false
extension SKPaymentQueue {
    
    public final class func doSwizzle() {
        guard !hasSwizzledPaymentQueue else { return }

        hasSwizzledPaymentQueue = true
        
        let original = #selector(self.add(_:) as (SKPaymentQueue) -> (SKPayment) -> Void)
        let swizzled = #selector(SKPaymentQueue.apphudAdd(_:))

        guard let swizzledMethod = class_getInstanceMethod(self, swizzled),
              let originalMethod = class_getInstanceMethod(self, original) else {
                apphudLog("couldn't swizzle")
                  return
              }
        method_exchangeImplementations(originalMethod, swizzledMethod)
    }
    
    @objc internal func apphudAdd(_ payment: SKPayment) {
        let currentUsername = payment.applicationUsername
        let currentUsernameIsUUID = (currentUsername != nil) && (UUID(uuidString: currentUsername!) != nil)
        
        if !currentUsernameIsUUID, let mutablePayment = payment as? SKMutablePayment ?? payment.mutableCopy() as? SKMutablePayment {
            mutablePayment.applicationUsername = ApphudStoreKitWrapper.shared.appropriateApplicationUsername()
            apphudAdd(mutablePayment)
        } else {
            apphudAdd(payment)
        }
    }
}
