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

@available(*, deprecated, message: "SDK purchases run on StoreKit 2 and no longer post SKPaymentTransaction notifications for them. Observer-mode (foreign SK1) transactions still post this.")
public let _ApphudWillFinishTransactionNotification = Notification.Name(rawValue: "ApphudWillFinishTransactionNotification")
@available(*, deprecated, message: "SDK purchases run on StoreKit 2 and no longer post SKPaymentTransaction notifications for them. Observer-mode (foreign SK1) transactions still post this.")
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

    var purchasingValue: ApphudCustomPurchaseValue?
    private(set) var isPurchasing: Bool = false

    internal var productsLoadTime: TimeInterval = 0.0

    // Master-parity receipt refreshing (see appStoreReceipt()). Callers can overlap
    // (two Transaction.updates deliveries, a restore during a purchase) and each one
    // awaits a continuation that must resume exactly once, so callbacks queue up
    // behind a single in-flight request instead of overwriting each other.
    private var refreshReceiptCallbacks: [() -> Void] = []
    private var refreshRequest: SKReceiptRefreshRequest?
    private var refreshWatchdog: DispatchWorkItem?
    /// StoreKit occasionally never calls back (no network, storekitd wedged). Waiting
    /// callers are released after this bound and proceed without a receipt — a stuck
    /// request must not block every later submission for the life of the process.
    internal var receiptRefreshTimeout: TimeInterval = 15
    /// Test seam: unit tests hand in a request whose `start()` never reaches StoreKit.
    internal var makeReceiptRefreshRequest: () -> SKReceiptRefreshRequest = { SKReceiptRefreshRequest() }

    func refreshReceipt(_ callback: (() -> Void)?) {
        DispatchQueue.main.async {
            if let callback {
                self.refreshReceiptCallbacks.append(callback)
            }
            // A refresh is already running: this caller is served by its completion.
            guard self.refreshRequest == nil else { return }
            let request = self.makeReceiptRefreshRequest()
            self.refreshRequest = request
            request.delegate = self
            request.start()

            let watchdog = DispatchWorkItem { [weak self, weak request] in
                guard let request else { return }
                self?.completeReceiptRefresh(request)
            }
            self.refreshWatchdog = watchdog
            DispatchQueue.main.asyncAfter(deadline: .now() + self.receiptRefreshTimeout, execute: watchdog)
        }
    }

    /// Every completion — finished, failed or timed out — releases all waiting callers.
    /// Master parity: a failed refresh never blocks the submission, the caller re-reads
    /// the (possibly still missing) receipt and proceeds.
    private func completeReceiptRefresh(_ request: SKRequest) {
        DispatchQueue.main.async {
            // Only the request in flight may release the waiting callers.
            guard request === self.refreshRequest else { return }
            request.cancel()
            self.refreshWatchdog?.cancel()
            self.refreshWatchdog = nil
            self.refreshRequest = nil
            let callbacks = self.refreshReceiptCallbacks
            self.refreshReceiptCallbacks.removeAll()
            callbacks.forEach { $0() }
        }
    }

    // MARK: - SKRequestDelegate (receipt refresh)

    func requestDidFinish(_ request: SKRequest) {
        if request is SKReceiptRefreshRequest {
            completeReceiptRefresh(request)
        }
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        if request is SKReceiptRefreshRequest {
            completeReceiptRefresh(request)
        }
    }

    func setupObserver() {
        SKPaymentQueue.default().add(self)
    }

    func enableSwizzle() {
        SKPaymentQueue.doSwizzle()
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

    /// Feeder fetch: populates the SKProduct cache (public `ApphudProduct.skProduct`)
    /// without driving the products fetch status — paywall readiness is keyed to the
    /// StoreKit 2 fetch and must not depend on this request.
    func fetchAllProductsFeeder(identifiers: Set<String>) async {
        guard identifiers.count > 0 else { return }

        let fetcher = ApphudProductsFetcher()
        fetchers.insert(fetcher)

        await withUnsafeContinuation { (continuation: UnsafeContinuation<Void, Never>) in
            fetcher.fetchStoreKitProducts(identifiers: identifiers) { products, _, ftchr in
                let existingIDS = self.products.map { $0.productIdentifier }
                let uniqueProducts = products.filter { !existingIDS.contains($0.productIdentifier) }
                var newProducts = self.products
                newProducts.append(contentsOf: uniqueProducts)
                self.products = newProducts
                self.fetchers.remove(ftchr)
                continuation.resume()
            }
        }

        // Re-associate skProduct on paywalls/placements once the feeder delivers.
        await MainActor.run {
            ApphudInternal.shared.updatePaywallsAndPlacements()
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

    // MARK: - SKPaymentTransactionObserver
    // The observer no longer initiates purchases (all SDK purchases go through
    // StoreKit 2). It exists to track purchases made by the host app's own
    // StoreKit 1 code (observer mode) and legacy twins of SK2 transactions.

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

                    if !ApphudUtils.shared.isFlutter {
                        // Do not access applicationUsername on Flutter to avoid crash
                        apphudLog("Payment is in purchasing state \(trx.payment.productIdentifier) for username: \(trx.payment.applicationUsername ?? "")")
                    }

                    // StoreKit 2 purchases made by the SDK also surface in the legacy
                    // payment queue, so observer mode must only be force-enabled when
                    // the SDK itself is not purchasing right now.
                    var sdkIsPurchasing = false
                    if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
                        sdkIsPurchasing = ApphudAsyncStoreKit.shared.isPurchasing
                    }

                    if !sdkIsPurchasing && ApphudUtils.shared.storeKitObserverMode == false {
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
                    // Restored transactions come only from a restore someone asked for.
                    ApphudInternal.shared.submitReceiptRestore(transaction: trx.original ?? trx, restore: true)
                    if !ApphudUtils.shared.storeKitObserverMode {
                        // force finish transaction; not ours, so the custom value of a
                        // purchase in flight must survive it
                        self.finishTransaction(trx, clearsPurchasingValue: false)
                    }
                case .deferred:
                    self.isPurchasing = false
                    self.handleDeferredTransaction(trx)
                    default:
                    self.isPurchasing = false
                }

                // A transaction check deferred while this purchase was in flight runs now.
                if !self.isPurchasing {
                    ApphudInternal.shared.runDeferredTransactionCheckIfNeeded()
                }
            }
        }
    }

    func handleDeferredTransaction(_ transaction: SKPaymentTransaction) {
        ApphudInternal.shared.delegate?.handleDeferredTransaction(transaction: transaction)
    }

    @MainActor
    private func handleTransactionIfStarted(_ transaction: SKPaymentTransaction) {

        // A failed transaction has no owner left to finish it now that the SK1 purchase
        // path is gone; left unfinished, StoreKit redelivers it on every launch. Handled
        // before the in-flight check so a failure arriving during an SDK purchase is not
        // skipped. Observer mode: the host finishes it, like every other state here.
        // The transaction is never the SDK's own purchase, so the custom value of a
        // purchase in flight must survive it.
        if transaction.transactionState == .failed {
            if transaction.failedWithUnknownReason {
                ApphudInternal.shared.setNeedToCheckTransactions()
            }
            if !ApphudUtils.shared.storeKitObserverMode {
                finishTransaction(transaction, clearsPurchasingValue: false)
            }
            return
        }

        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *), ApphudAsyncStoreKit.shared.isPurchasing {
            return
        }

        if transaction.transactionState == .purchased {
            // Another account's transaction is left to StoreKit 2, which keeps it for its owner. Its
            // StoreKit 2 twin carries the token, looked up only once a user with a UUID id bought here.
            if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *),
               let trxIdInt = transaction.transactionIdentifier.flatMap({ UInt64($0) }),
               !ApphudInternal.shared.isIdentityV1, !ApphudStoreKitWrapper.purchaseUserTokens().isEmpty {
                let productID = transaction.payment.productIdentifier
                Task { @MainActor in
                    if let other = await ApphudInternal.shared.anotherAccountsTransaction(id: trxIdInt, productID: productID) {
                        apphudLog("Transaction \(trxIdInt) belongs to another account, skipping", logLevel: .debug)
                        // As in StoreKit 2: a later transaction of a subscription may be finished, a
                        // first purchase waits for its owner.
                        if other.originalID != other.id && !ApphudUtils.shared.storeKitObserverMode {
                            self.finishTransaction(transaction, clearsPurchasingValue: false)
                        }
                        return
                    }
                    self.handlePurchased(transaction)
                }
                return
            }
            handlePurchased(transaction)
        }
    }

    @MainActor
    private func handlePurchased(_ transaction: SKPaymentTransaction) {
        if !ApphudInternal.shared.isIdentityV1 {
            handleObservedPurchaseV2(transaction)
            return
        }
        if let trxId = transaction.transactionIdentifier, let trxIdInt = UInt64(trxId) {
            // A StoreKit 2 submission for this transaction is still in flight: its
            // owner decides whether it may be finished, so leave it alone and
            // re-check afterwards.
            if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *),
               ApphudAsyncStoreKit.isProcessing(transactionID: trxIdInt) {
                ApphudInternal.shared.setNeedToCheckTransactions()
                return
            }

            // Legacy queue twin of a transaction the backend already acknowledged via
            // StoreKit 2. In observer mode the host owns finishing it, exactly like
            // the other finish sites in this file.
            if ApphudInternal.shared.lastUploadedTransactions.contains(trxIdInt) {
                if !ApphudUtils.shared.storeKitObserverMode {
                    finishTransaction(transaction)
                }
                return
            }
        }

        ApphudInternal.shared.submitReceiptAutomaticPurchaseTracking(transaction: transaction) { result in
            if let finish = ApphudInternal.shared.delegate?.apphudDidObservePurchase(result: result), finish == true {
                self.finishTransaction(transaction)
            } else if ApphudUtils.shared.storeKitObserverMode == false && result.success {
                self.finishTransaction(transaction)
            }
        }
    }

    @MainActor
    private func handleObservedPurchaseV2(_ transaction: SKPaymentTransaction) {
        let sdk = ApphudInternal.shared
        let identity = sdk.identity
        let generation = sdk.observedTransactions.generation
        guard let id = transaction.transactionIdentifier.flatMap(UInt64.init) else {
            sdk.submitReceiptAutomaticPurchaseTracking(transaction: transaction) { result in
                guard generation == sdk.observedTransactions.generation, identity.hasSameIDs(as: sdk.identity) else { return }
                let finish = sdk.delegate?.apphudDidObservePurchase(result: result) == true
                if result.error == nil && (finish || (!ApphudUtils.shared.storeKitObserverMode && result.success)) {
                    self.finishTransaction(transaction)
                }
            }
            return
        }
        guard !sdk.observedTransactions.isSDKPurchase(id) else { return }
        if sdk.lastUploadedTransactions.contains(id), sdk.submittingTransaction != String(id),
           !sdk.observedTransactions.hasAcknowledgement(id, identity: identity) {
            // Historical acknowledgement: no new observed event, as before.
            if !ApphudUtils.shared.storeKitObserverMode,
               sdk.observedTransactions.claimFinish(id, generation: generation) { finishTransaction(transaction) }
            return
        }
        guard let ticket = sdk.observedTransactions.beginObservation(id, identity: identity) else { return }
        let complete: (ApphudPurchaseResult) -> Void = { result in
            guard generation == sdk.observedTransactions.generation, identity.hasSameIDs(as: sdk.identity) else {
                sdk.observedTransactions.cancelObservation(id, ticket: ticket)
                return
            }
            guard sdk.observedTransactions.completeObservation(id, ticket: ticket, success: result.error == nil) else { return }
            let finish = sdk.delegate?.apphudDidObservePurchase(result: result) == true
            if result.error == nil && (finish || (!ApphudUtils.shared.storeKitObserverMode && result.success)),
               sdk.observedTransactions.claimFinish(id, generation: generation) {
                self.finishTransaction(transaction)
            }
        }
        if sdk.submittingTransaction != String(id), sdk.observedTransactions.hasAcknowledgement(id, identity: identity) {
            complete(sdk.purchaseResult(productId: transaction.payment.productIdentifier, transaction: transaction, error: nil))
        } else {
            // Same-id submissions join at submitReceipt, including while its response is parsed.
            sdk.submitReceiptAutomaticPurchaseTracking(transaction: transaction, callback: complete)
        }
    }

    internal func finishTransaction(_ transaction: SKPaymentTransaction, clearsPurchasingValue: Bool = true) {
        apphudLog("Finish Transaction: \(transaction.payment.productIdentifier), state: \(transaction.transactionState.rawValue), id: \(transaction.transactionIdentifier ?? "")")
        NotificationCenter.default.post(name: _ApphudWillFinishTransactionNotification, object: transaction)

        if transaction.transactionState != .purchasing {
            SKPaymentQueue.default().finishTransaction(transaction)
        }
        if clearsPurchasingValue {
            self.purchasingValue = nil
        }
    }

    func paymentQueue(_ queue: SKPaymentQueue, removedTransactions transactions: [SKPaymentTransaction]) {
        DispatchQueue.main.async {
            transactions.forEach { transaction in
                NotificationCenter.default.post(name: _ApphudDidFinishTransactionNotification, object: transaction)
            }
        }
    }

    // Promoted in-app purchases are handled via StoreKit 2 PurchaseIntent.intents
    // (see ApphudPurchaseIntentsObserver). Per Apple's documentation, an app must not
    // use both PurchaseIntent and paymentQueue(_:shouldAddStorePayment:for:) at the
    // same time, so the SK1 handler was removed with the StoreKit 2 migration.

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
        return Self.applicationUsername()
    }

    /// The current application username.
    static func applicationUsername() -> String {
        let sdk = ApphudInternal.shared
        guard sdk.isIdentityV1 else { return applicationUsername(for: sdk.identity) }
        return applicationUsernameV1(userID: sdk.currentUserID, deviceID: sdk.currentDeviceID)
    }

    /// Identity version 1: the user id when it is a UUID, otherwise the device id, as SDK 4.6 did.
    static func applicationUsernameV1(userID: String, deviceID: String) -> String {
        let userIDIsUUID = UUID(uuidString: userID)
        return (userIDIsUUID != nil) ? userID : deviceID
    }

    /// The identified user's id when it is a UUID, otherwise the installation id, as the old device id
    /// was. Never the anonymous id: the backend stops finding its customer after identify and merge.
    static func applicationUsername(for identity: ApphudIdentity) -> String {
        let userID = identity.userID ?? ""
        let userIDIsUUID = UUID(uuidString: userID)
        return (userIDIsUUID != nil) ? userID : identity.installationID
    }

    /// The `appAccountToken` sent with StoreKit 2 purchases: the application username when it is a UUID.
    /// A promotional offer is signed for this token in lowercase, or for an empty string when there is none.
    static func appAccountToken(from applicationUsername: String?) -> UUID? {
        applicationUsername.flatMap { UUID(uuidString: $0) }
    }

    /// The token the SDK's own purchases carry, whether or not the StoreKit 1 swizzle is on. Identity
    /// version 1: only once the payment queue is swizzled, as SDK 4.6 did.
    internal func appAccountToken() -> UUID? {
        guard !ApphudInternal.shared.isIdentityV1 else { return Self.appAccountToken(from: appropriateApplicationUsername()) }
        return Self.appAccountToken(from: Self.applicationUsername(for: ApphudInternal.shared.identity))
    }

    /// User ids this install's SDK purchases carried as `appAccountToken`. Logout keeps them: a
    /// transaction with one of them stays that user's after someone else signs in.
    static let purchaseUserTokensKey = "com.apphud.purchase_user_tokens"

    /// Remembers a purchase's token when it is the user's id, not the installation id.
    static func rememberPurchaseToken(_ token: UUID, identity: ApphudIdentity, defaults: UserDefaults = .standard) {
        guard let userID = identity.userID, UUID(uuidString: userID) == token else { return }
        let tokens = purchaseUserTokens(defaults: defaults)
        guard !tokens.contains(token) else { return }
        defaults.set((tokens + [token]).map(\.uuidString), forKey: purchaseUserTokensKey)
    }

    static func purchaseUserTokens(defaults: UserDefaults = .standard) -> [UUID] {
        (defaults.stringArray(forKey: purchaseUserTokensKey) ?? []).compactMap { UUID(uuidString: $0) }
    }

    /// The token is the id of another user who bought on this install. A token the SDK never put
    /// there (the app's own, another device's, an installation id) names no account.
    static func belongsToAnotherAccount(_ token: UUID?, identity: ApphudIdentity, purchaseUserTokens: [UUID]) -> Bool {
        guard let token, purchaseUserTokens.contains(token) else { return false }
        return token != appAccountToken(from: applicationUsername(for: identity))
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

    func fetchStoreKitProducts(identifiers: Set<String>, callback: @escaping ApphudStoreKitFetcherCallback) {
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

        var error: ApphudError?

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
