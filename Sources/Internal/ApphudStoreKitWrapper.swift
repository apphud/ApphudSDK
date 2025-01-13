//
//  ApphudStoreKitFetcher.swift
//  subscriptionstest
//
//  Created by ren6 on 01/07/2019.
//  Copyright © 2019 apphud. All rights reserved.
//

import Foundation
import StoreKit
internal typealias ApphudCustomPurchaseValue = (productId: String, value: Double)
internal typealias ApphudStoreKitProductsCallback = ([SKProduct], Error?) -> Void
private typealias ApphudStoreKitFetcherCallback = ([SKProduct], Error?, ApphudProductsFetcher) -> Void
internal typealias ApphudTransactionCallback = (SKPaymentTransaction, Error?) -> Void

public let _ApphudWillFinishTransactionNotification = Notification.Name(rawValue: "ApphudWillFinishTransactionNotification")
public let _ApphudDidFinishTransactionNotification = Notification.Name(rawValue: "ApphudDidFinishTransactionNotification")

enum ApphudStoreKitProductsFetchStatus {
    case none
    case loading
    case fetched
    case error(ApphudError?)
}

internal class ApphudStoreKitWrapper: NSObject, SKPaymentTransactionObserver, SKRequestDelegate {
    static var shared = ApphudStoreKitWrapper()

    private var _products = [SKProduct]()
    private let productsQueue = DispatchQueue(label: "com.apphud.StoreKitProductsQueue", attributes: .concurrent)
    
    internal var products: [SKProduct] {
        get {
            productsQueue.sync {
                return self._products
            }
        }
        set {
            productsQueue.async(flags: .barrier) {
                self._products = newValue
            }
        }
    }

    internal var status: ApphudStoreKitProductsFetchStatus = .none

    fileprivate var fetchers = ApphudSafeSet<ApphudProductsFetcher>()

    private var refreshReceiptCallback: (() -> Void)?
    private var paymentCallback: ApphudTransactionCallback?

    var purchasingProductID: String?
    var purchasingValue: ApphudCustomPurchaseValue?
    private(set) var isPurchasing: Bool = false

    internal var loadingAll: Bool = false
    
    private var refreshRequest: SKReceiptRefreshRequest?

    internal var productsLoadTime: TimeInterval = 0.0

    func setupObserver() {
        SKPaymentQueue.default().add(self)
    }

    func enableSwizzle() {
        SKPaymentQueue.doSwizzle()
    }

    func restoreTransactions() {

        Task { @MainActor in
            SKPaymentQueue.default().restoreCompletedTransactions()
        }
    }
    
    func latestError() -> Error? {
        switch status {
        case .none:
            return nil
        case .loading:
            return nil
        case .fetched:
            return nil
        case .error(let error):
            return error
        }
    }

    func refreshReceipt(_ callback: (() -> Void)?) {
        refreshReceiptCallback = callback
        refreshRequest = SKReceiptRefreshRequest()
        refreshRequest?.delegate = self
        refreshRequest?.start()
    }

    func fetchAllProducts(identifiers: Set<String>) async -> ([SKProduct], ApphudError?) {
        loadingAll = true
        apphudLog("Started Fetching All Products")
        self.status = .loading
        
        let fetcher = ApphudProductsFetcher()
        fetchers.insert(fetcher)
        
        return await withUnsafeContinuation { continuation in
            fetcher.fetchStoreKitProducts(identifiers: identifiers) { products, error, ftchr in
                let existingIDS = self.products.map { $0.productIdentifier }
                let uniqueProducts = products.filter { !existingIDS.contains($0.productIdentifier) }
                var newProducts = self.products
                newProducts.append(contentsOf: uniqueProducts)
                self.products = newProducts
                var aphError: ApphudError?
                if let error = error {
                    aphError = ApphudError(error: error)
                }
                
                self.status = newProducts.count > 0 ? .fetched : .error(aphError)
                self.fetchers.remove(ftchr)
                self.loadingAll = false
                continuation.resume(returning: (products, aphError))
            }
        }
    }

    func fetchProduct(_ productId: String) async -> SKProduct? {

        if let availableProduct = products.first(where: { $0.productIdentifier == productId }) {
            return availableProduct
        }

        return await withUnsafeContinuation { continuation in
            fetchProducts(productIds: [productId]) { prds in
                continuation.resume(returning: prds?.first(where: { $0.productIdentifier == productId }))
            }
        }
    }

    func fetchProducts(_ productIds: [String]) async -> [SKProduct]? {

        var available = [SKProduct]()
        productIds.forEach { id in
            if let p = products.first(where: { $0.productIdentifier == id }) {
                available.append(p)
            }
        }

        if available.count == productIds.count {
            return available
        }

        return await withUnsafeContinuation { continuation in
            fetchProducts(productIds: productIds) { products in
                continuation.resume(returning: products)
            }
        }
    }

    func fetchProducts(productIds: [String], callback: @escaping ([SKProduct]?) -> Void) {
        let fetcher = ApphudProductsFetcher()
        fetchers.insert(fetcher)

        fetcher.fetchStoreKitProducts(identifiers: Set(productIds)) { prds, _, ftchr in

            var available = [SKProduct]()
            productIds.forEach { id in
                if let p = prds.first(where: { $0.productIdentifier == id }) {
                    available.append(p)
                }
            }

            callback(available)

            self.fetchers.remove(ftchr)
        }
    }

    func purchase(product: SKProduct, value: Double? = nil, callback: @escaping ApphudTransactionCallback) {
        ApphudUtils.shared.storeKitObserverMode = false
        let payment = SKMutablePayment(product: product)
        purchase(payment: payment, value: value, callback: callback)
    }

    func purchase(product: SKProduct, discount: SKPaymentDiscount, callback: @escaping ApphudTransactionCallback) {
        ApphudUtils.shared.storeKitObserverMode = false
        let payment = SKMutablePayment(product: product)
        payment.paymentDiscount = discount
        purchase(payment: payment, callback: callback)
    }

    func purchase(payment: SKPayment, value: Double? = nil, callback: @escaping ApphudTransactionCallback) {
        finishCompletedTransactions(for: payment.productIdentifier)
        paymentCallback = callback
        purchasingProductID = payment.productIdentifier
        if let v = value {
            purchasingValue = ApphudCustomPurchaseValue(payment.productIdentifier, v)
        } else {
            purchasingValue = nil
        }
        apphudLog("Starting payment for \(payment.productIdentifier), transactions in queue: \(SKPaymentQueue.default().transactions)")
        SKPaymentQueue.default().add(payment)
    }

    // MARK: - SKPaymentTransactionObserver

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        Task { @MainActor in

            // order purchased state before any others
            let sortedTransactions = transactions.sorted { first, _ in
                first.transactionState == .purchased
            }

            for trx in sortedTransactions {
                switch trx.transactionState {
                case .purchasing:
                    self.isPurchasing = true

                    Task { @MainActor in
                        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
                            try? await ApphudAsyncStoreKit.shared.fetchProductIfNeeded(trx.payment.productIdentifier)
                        }
                    }

                    if !ApphudUtils.shared.isFlutter {
                        // Do not access applicationUsername on Flutter to avoid crash
                        apphudLog("Payment is in purchasing state \(trx.payment.productIdentifier) for username: \(trx.payment.applicationUsername ?? "")")
                    }

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
        ApphudInternal.shared.delegate?.handleDeferredTransaction(transaction: transaction)
    }

    private func handleTransactionIfStarted(_ transaction: SKPaymentTransaction) {

        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *), ApphudAsyncStoreKit.shared.isPurchasing {
            return
        }

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
                    if let finish = ApphudInternal.shared.delegate?.apphudDidObservePurchase(result: result), finish == true {
                        self.finishTransaction(transaction)
                    } else if ApphudUtils.shared.storeKitObserverMode == false && result.success {
                        self.finishTransaction(transaction)
                    }
                }
            } else if transaction.failedWithUnknownReason {
                ApphudInternal.shared.setNeedToCheckTransactions()
            }
        }
    }

    private func finishCompletedTransactions(for productIdentifier: String) {
        let transactionsCopy = SKPaymentQueue.default().transactions
        
        transactionsCopy
            .filter { $0.payment.productIdentifier == productIdentifier && $0.finishable }
            .forEach { transaction in finishTransaction(transaction) }
    }

    internal func finishTransaction(_ transaction: SKPaymentTransaction) {
        apphudLog("Finish Transaction: \(transaction.payment.productIdentifier), state: \(transaction.transactionState.rawValue), id: \(transaction.transactionIdentifier ?? "")")
        NotificationCenter.default.post(name: _ApphudWillFinishTransactionNotification, object: transaction)
    
        if (transaction.transactionState != .purchasing) {
            SKPaymentQueue.default().finishTransaction(transaction)
        }
        self.purchasingProductID = nil
        self.purchasingValue = nil
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
            if let callback = ApphudInternal.shared.delegate?.apphudShouldStartAppStoreDirectPurchase(product) {
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
            }
            request.cancel()
            self.refreshRequest = nil
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
            }
            request.cancel()
            self.refreshRequest = nil
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
private class ApphudProductsFetcher: NSObject, SKProductsRequestDelegate, Identifiable {

    var id = UUID()

    private var callback: ApphudStoreKitFetcherCallback?

    private var productsRequest: SKProductsRequest?

    var retries: Int = 3
    var attempt: Int = 0

    var identifiers: Set<String>?

    func fetchStoreKitProducts(identifiers: Set<String>, callback : @escaping ApphudStoreKitFetcherCallback) {
        self.callback = callback
        self.identifiers = identifiers
        performFetch()
    }

    func performFetch() {
        guard let ids = identifiers else {return}
        productsRequest?.delegate = nil
        productsRequest?.cancel()
        productsRequest = SKProductsRequest(productIdentifiers: ids)
        productsRequest?.delegate = self
        productsRequest?.start()

        apphudLog("Fetcher [\(id.uuidString)] Started Requesting Products: \(ids)", logLevel: .debug)
    }

    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        
        var error: ApphudError? = nil
        
        if response.invalidProductIdentifiers.count > 0 && response.products.count == 0 {
            
            error = ApphudError(message: "StoreKit Products Not Available. For more details visit: https://docs.apphud.com/docs/troubleshooting#storekit-products-not-available-error")
            
            apphudLog("Failed to load SKProducts from the App Store, because product identifiers are invalid:\n \(response.invalidProductIdentifiers)\n\tFor more details visit: https://docs.apphud.com/docs/troubleshooting#storekit-products-not-available-error", forceDisplay: true)
        }
        
        if response.products.count > 0 {
            apphudLog("Fetcher [\(id.uuidString)] Successfully fetched SKProducts from the App Store:\n \(response.products.map { $0.productIdentifier })")
        }
        self.callback?(response.products, error, self)
        self.callback = nil
        self.productsRequest = nil
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        if (error as NSError).description.contains("Attempted to decode store response") {
            apphudLog("Failed to load SKProducts from the App Store, error: \(error). [!] App Store features in iOS Simulator are not supported. For more details visit: https://docs.apphud.com/docs/troubleshooting#attempted-to-decode-store-response-error-while-fetching-products", forceDisplay: true)
        } else {
            apphudLog("Failed to load SKProducts from the App Store, error: \(error)", forceDisplay: true)
        }

        if attempt < retries {
            attempt += 1
            performFetch()
        } else {
            self.callback?([], error, self)
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

            // avoid issues with mutableCopy function
            let validate = (mutablePayment.productIdentifier as NSString).responds(to: Selector(("length")))

            if validate && mutablePayment.productIdentifier.count > 0 {
                mutablePayment.applicationUsername = ApphudStoreKitWrapper.shared.appropriateApplicationUsername()
                apphudAdd(mutablePayment)
            } else {
                apphudAdd(payment)
            }
        } else {
            apphudAdd(payment)
        }
    }
}
