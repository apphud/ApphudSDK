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

#if os(visionOS)
import UIKit
#endif

extension ApphudInternal {

    // MARK: - Main Purchase and Submit Receipt methods

    @MainActor internal func migrateiOS14PurchasesIfNeeded() {
        if apphudShouldMigrate() {
            ApphudInternal.shared.restorePurchases { result in
                if result.error == nil {
                    apphudDidMigrate()
                }
            }
        }
    }

    @MainActor internal func restorePurchases(callback: @escaping (ApphudPurchaseResult) -> Void) {
        self.restorePurchasesCallback = { subs, purchases, error in
            let activeSub = subs?.first { $0.isActive() }
            let activePurch = purchases?.first { $0.isActive() }

            let result = ApphudPurchaseResult(activeSub, activePurch, nil, error)
            result.isRestoreResult = true
            callback(result)
        }

        if #available(iOS 15.0, tvOS 15.0, watchOS 8.0, macOS 12.0, *) {
            Task {
                await restoreUsingStoreKit2()
            }
        } else {
            self.submitReceiptRestore(transaction: nil)
        }
    }

    /// Restore semantics (StoreKit 2): silently walk `Transaction.currentEntitlements`
    /// first; only when the device has no entitlements at all, call `AppStore.sync()`
    /// once (shows the system authentication sheet) and walk again.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    internal func restoreUsingStoreKit2() async {

        func latestEntitlement() async -> VerificationResult<StoreKit.Transaction>? {
            var latest: VerificationResult<StoreKit.Transaction>?
            for await result in StoreKit.Transaction.currentEntitlements {
                if case .verified(let transaction) = result {
                    if latest == nil || latest!.unsafePayloadValue.purchaseDate < transaction.purchaseDate {
                        latest = result
                    }
                }
            }
            return latest
        }

        var latest = await latestEntitlement()

        // AppStore.sync() shows the system authentication sheet, so it is a last resort:
        // only when the device has neither entitlements nor an App Store receipt to
        // submit (master parity — the receipt path was always silent).
        if latest == nil && apphudReceiptDataString() == nil {
            apphudLog("No entitlements and no receipt on device, requesting AppStore.sync()..")
            do {
                try await AppStore.sync()
                latest = await latestEntitlement()
            } catch {
                apphudLog("AppStore.sync() failed or was canceled by user: \(error)")
            }
        }

        let receiptString = apphudReceiptDataString()
        let transaction = latest.map { $0.unsafePayloadValue }
        let jws = latest?.jwsRepresentation

        if receiptString == nil && transaction == nil {
            let error = ApphudError(message: "Failed to restore purchases: neither entitlements nor App Store receipt found on device.")
            apphudLog(error.localizedDescription, forceDisplay: true)
            await MainActor.run {
                self.restorePurchasesCallback?(self.currentUser?.subscriptions, self.currentUser?.purchases, error)
                self.restorePurchasesCallback = nil
            }
            return
        }

        performWhenUserRegistered {
            Task {
                await self.submitReceipt(productInfo: nil,
                                         apphudProduct: nil,
                                         transactionIdentifier: transaction.map { String($0.id) },
                                         transactionProductIdentifier: transaction?.productID,
                                         transactionState: nil,
                                         receiptString: receiptString,
                                         transactionJws: jws,
                                         notifyDelegate: true,
                                         fromScreen: false) { error in
                    Task { @MainActor in
                        self.restorePurchasesCallback?(self.currentUser?.subscriptions, self.currentUser?.purchases, error)
                        self.restorePurchasesCallback = nil
                    }
                }
            }
        }
    }

    /// Runs a transaction check that was deferred because a purchase was in flight.
    @MainActor internal func runDeferredTransactionCheckIfNeeded() {
        guard deferredTransactionCheck else { return }
        deferredTransactionCheck = false
        setNeedToCheckTransactions()
    }

    internal func setNeedToCheckTransactions() {
        apphudPerformOnMainThread {
            NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.checkTransactionsNow), object: nil)
            self.perform(#selector(self.checkTransactionsNow), with: nil, afterDelay: 0.5)
        }
    }

    @MainActor @objc internal func checkTransactionsNow() {

        // A purchase is in flight: it delivers its own transaction. Remember the check
        // instead of dropping it — otherwise a failed submission is never re-attempted —
        // and run it when the purchase completes rather than polling meanwhile.
        if ApphudStoreKitWrapper.shared.isPurchasing {
            deferredTransactionCheck = true
            return
        }

        if #available(iOS 15.0, tvOS 15.0, watchOS 8.0, macOS 12.0, *) {

            if ApphudAsyncStoreKit.shared.isPurchasing {
                deferredTransactionCheck = true
                return
            }

            Task(priority: .background) {
                if let latestResult = await ApphudAsyncStoreKit.shared.fetchLatestTransaction(),
                   case .verified(let latestTransaction) = latestResult {
                    // Submits only — finishing a transaction belongs to whoever owns it
                    // (the purchase call or the updates listener). In observer mode the
                    // host finishes its own transactions and this must not interfere.
                    await handleTransaction(latestTransaction, jws: latestResult.jwsRepresentation)
                }
            }
        }
    }

    /// Returns `true` when the transaction needs no further delivery (already tracked,
    /// inactive, or submitted successfully) — the caller may finish it. Returns `false`
    /// when the submission failed or was skipped mid-flight, so an unfinished
    /// transaction gets redelivered by StoreKit and retried.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @discardableResult internal func handleTransaction(_ transaction: StoreKit.Transaction, jws: String? = nil, fromScreen: Bool = false) async -> Bool {
        let transactionId = transaction.id
        let refundDate = transaction.revocationDate
        let expirationDate = transaction.expirationDate
        let purchaseDate = transaction.purchaseDate
        let upgrade = transaction.isUpgraded
        let productID = transaction.productID

        // A submission for this exact transaction is still in flight: its owner decides
        // whether the transaction may be finished, so report "not handled" here.
        if await self.submittingTransaction == String(transactionId) {
            apphudLog("Already submitting the same transaction id \(transactionId), skipping", logLevel: .debug)
            return false
        }

        // use original transaction id to compare if already tracked
        if await isAlreadyTracked(transactionId: transaction.originalID, productId: productID, purchaseDate: purchaseDate) {
            apphudLog("This transaction already tracked by Apphud: \(transactionId), skipping", logLevel: .debug)
            return true
        }

        let transactions = await self.lastUploadedTransactions
        if transactions.contains(transactionId) {
            return true
        }

        var isActive = false
        switch transaction.productType {
        case .autoRenewable:
            isActive = expirationDate != nil && expirationDate! > Date() && refundDate == nil && upgrade == false
        default:
            isActive = refundDate == nil
        }

        if isActive {
            apphudLog("found transaction with ID: \(transactionId), \(productID), purchase date: \(purchaseDate)", logLevel: .debug)

            // StoreKit 2 path: product metadata comes from the SK2 product cache,
            // no SKProductsRequest involved.
            let product = try? await ApphudAsyncStoreKit.shared.fetchProduct(productID)
            let receipt = await appStoreReceipt()
            let isRecentlyPurchased: Bool = purchaseDate > Date().addingTimeInterval(-3600)
            return await withUnsafeContinuation { continuation in
                // allowFailure: a block that waits for a registration which never succeeds
                // is never released, which would hang the purchase call awaiting it.
                performWhenUserRegistered(allowFailure: true) {

                    guard self.currentUser != nil else {
                        apphudLog("Cannot submit transaction \(transactionId) because user is not registered, will retry later", forceDisplay: true)
                        continuation.resume(returning: false)
                        return
                    }

                    apphudLog("Submitting transaction \(transactionId), \(productID) from StoreKit2.. Is recently purchased: \(isRecentlyPurchased)")

                    // The id is recorded as uploaded by submitReceipt once it owns the
                    // submission — marking it here would strand the transaction if the
                    // submission never started.
                    Task {
                        await self.submitReceipt(productInfo: product?.apphudSubmittableParameters(isRecentlyPurchased),
                                           apphudProduct: nil,
                                           transactionIdentifier: String(transactionId),
                                           transactionProductIdentifier: productID,
                                           transactionState: isRecentlyPurchased ? .purchased : nil,
                                           receiptString: receipt,
                                           transactionJws: jws,
                                                 notifyDelegate: true,
                                                 ownsTransaction: true,
                                                 fromScreen: fromScreen) { error in
                            continuation.resume(returning: error == nil)
                        }
                    }
                }
            }
        }
        return true
    }

    fileprivate func isAlreadyTracked(transactionId: UInt64, productId: String, purchaseDate: Date) async -> Bool {

        var trackedPurchases = await (ApphudInternal.shared.currentUser?.purchases ?? []).map { ($0.productId, $0.transactionId, $0.purchasedAt) }
        let trackedSubs = await (ApphudInternal.shared.currentUser?.subscriptions ?? []).map { ($0.productId, $0.originalTransactionId, $0.startedAt) }

        trackedPurchases.append(contentsOf: trackedSubs)

        for (pID, trxID, purchDate) in trackedPurchases {
            if pID == productId && (abs(purchDate.timeIntervalSince(purchaseDate)) < 2 || trxID == String(transactionId)) {
                return true
            }
        }

        return false
    }

    internal func appStoreReceipt() async -> String? {
        // No SKReceiptRefreshRequest anymore: a missing receipt no longer blocks
        // submission — the transaction id and JWS identify the purchase.
        apphudReceiptDataString()
    }

    internal func submitReceiptAutomaticPurchaseTracking(transaction: SKPaymentTransaction, callback: @escaping ((ApphudPurchaseResult) -> Void)) {

        performWhenUserRegistered {

            let receiptString = apphudReceiptDataString()

            if receiptString == nil {
                apphudLog("App Store receipt is missing, but got transaction. Will try to submit transaction instead..", forceDisplay: true)
            }

            // The completion may finish this SK1 transaction, so this submission owns it
            // and must never be answered by a foreign submission's result.
            self.submitReceipt(product: nil, apphudProduct: nil, transaction: transaction, receiptString: receiptString, notifyDelegate: true, eligibilityCheck: true, ownsTransaction: true, fromScreen: false, callback: { error in
                let result = self.purchaseResult(productId: transaction.payment.productIdentifier, transaction: transaction, error: error)
                callback(result)
            })
        }
    }

    @objc internal func submitAppStoreReceipt() {
        // Receipt submission retry: re-check the latest StoreKit 2 transaction and
        // resubmit (a failed submission releases its own id from lastUploadedTransactions).
        // Known limitation: this retries the newest transaction, so an older failed one
        // waits for its next redelivery by StoreKit instead of being retried here.
        Task { @MainActor in
            if #available(iOS 15.0, tvOS 15.0, watchOS 8.0, macOS 12.0, *) {
                checkTransactionsNow()
            } else {
                submitReceiptRestore(transaction: nil)
            }
        }
    }

    @MainActor internal func submitReceiptRestore(transaction: SKPaymentTransaction?) {

        let receiptString = apphudReceiptDataString()

        if receiptString == nil && transaction?.transactionIdentifier == nil {
            let error = ApphudError(message: "Failed to restore purchases because App Store receipt is missing on device.")
            apphudLog(error.localizedDescription, forceDisplay: true)
            self.restorePurchasesCallback?(self.currentUser?.subscriptions, self.currentUser?.purchases, error)
            self.restorePurchasesCallback = nil
            return
        } else if receiptString == nil && transaction?.transactionIdentifier != nil {
            apphudLog("App Store receipt is missing, but got transaction. Will try to submit transaction instead..", forceDisplay: true)
        }

        performWhenUserRegistered {

            self.submitReceipt(product: nil, apphudProduct: nil, transaction: transaction, receiptString: receiptString, notifyDelegate: true, fromScreen: false) { error in
                self.restorePurchasesCallback?(self.currentUser?.subscriptions, self.currentUser?.purchases, error)
                self.restorePurchasesCallback = nil
            }
        }
    }

    internal func submitReceipt(product: SKProduct?, apphudProduct: ApphudProduct?, transaction: SKPaymentTransaction?, receiptString: String?, notifyDelegate: Bool, eligibilityCheck: Bool = false, ownsTransaction: Bool = false, fromScreen: Bool, callback: ApphudNSErrorCallback?) {

        let productId = product?.productIdentifier ?? transaction?.payment.productIdentifier
        let finalProduct = product ?? ApphudStoreKitWrapper.shared.products.first(where: { $0.productIdentifier == productId })

        let block: ((SKProduct?) -> Void) = { pr in
            let hasMadePurchase = transaction?.transactionState == .purchased
            Task {
                await self.submitReceipt(productInfo: pr?.apphudSubmittableParameters(hasMadePurchase),
                                   apphudProduct: apphudProduct,
                                   transactionIdentifier: transaction?.transactionIdentifier,
                                   transactionProductIdentifier: productId,
                                   transactionState: transaction?.transactionState,
                                   receiptString: receiptString,
                                   notifyDelegate: notifyDelegate,
                                   eligibilityCheck: eligibilityCheck,
                                   ownsTransaction: ownsTransaction,
                                   fromScreen: fromScreen,
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

    internal func submitReceipt(productInfo: [String: Any]?,
                                apphudProduct: ApphudProduct?,
                                transactionIdentifier: String?,
                                transactionProductIdentifier: String?,
                                transactionState: SKPaymentTransactionState?,
                                receiptString: String?,
                                transactionJws: String? = nil,
                                notifyDelegate: Bool,
                                eligibilityCheck: Bool = false,
                                // True only for the submission that owns a StoreKit 2
                                // transaction and decides whether it may be finished.
                                ownsTransaction: Bool = false,
                                fromScreen: Bool,
                                callback: ApphudNSErrorCallback?) async {

        let newClaim = transactionIdentifier ?? transactionProductIdentifier ?? (productInfo?["product_id"] as? String) ?? "Restoration"

        // Claim the single-flight slot atomically. A submission that OWNS a transaction
        // must never be answered by another submission's result: its caller decides
        // whether that transaction may be finished, and a foreign success would finish a
        // transaction nobody uploaded. Every other caller (restore, eligibility checks,
        // observer-mode tracking) still piggybacks on the in-flight upload as before.
        let inFlight: String? = await MainActor.run {
            let existing = self.submittingTransaction

            if existing == nil {
                self.submittingTransaction = newClaim
            }

            if let callback, existing == nil || !ownsTransaction {
                if eligibilityCheck || self.submitReceiptCallbacks.count > 0 {
                    self.submitReceiptCallbacks.append(callback)
                } else {
                    self.submitReceiptCallbacks = [callback]
                }
            }

            return existing
        }

        if let inFlight {
            // The in-flight submission IS this very transaction (its SK1 twin or a
            // duplicate delivery): answering the owner with its result is safe and
            // correct — rejecting it would report a bogus failure for a routine purchase.
            if ownsTransaction && inFlight != newClaim {
                let message = "Already submitting another receipt (\(inFlight)), transaction \(transactionIdentifier ?? newClaim) stays unfinished and will be retried"
                apphudLog(message)
                // Re-attempt shortly instead of waiting for StoreKit to redeliver.
                setNeedToCheckTransactions()
                await MainActor.run { callback?(ApphudError(message: message)) }
            } else {
                apphudLog("Already submitting some receipt (\(inFlight)), this caller will receive its result")
            }
            return
        }

        let environment = Apphud.isSandbox() ? ApphudEnvironment.sandbox.rawValue : ApphudEnvironment.production.rawValue

        var params: [String: Any] = ["device_id": self.currentDeviceID,
                                     "environment": environment,
                                     "observer_mode": ApphudUtils.shared.storeKitObserverMode]

        // Send the receipt whenever it is readable from disk: apps without an
        // App Store Server API key in the Apphud dashboard can only be validated
        // by receipt on the backend.
        if let receipt = receiptString {
            params["receipt_data"] = receipt
        }

        if let transactionID = transactionIdentifier {
            params["transaction_id"] = transactionID
        }
        // Signed StoreKit 2 transaction (JWS). Backend can verify it locally against
        // Apple's certificate chain without an App Store Server API key.
        if let transactionJws {
            params["jws"] = transactionJws
        }
        if let bundleID = Bundle.main.bundleIdentifier {
            params["bundle_id"] = bundleID
        }

        let hasMadePurchase = transactionState == .purchased

        params["user_id"] = currentUserID

        if let info = productInfo {
            params["product_info"] = info
        }

        if hasMadePurchase, let purchasedApphudProduct = apphudProduct ?? purchasingProduct, purchasedApphudProduct.productId == transactionProductIdentifier {
            
            if fromScreen {
                params["screen_id"] = purchasedApphudProduct.paywall?.screen?.id
            }
            
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
        
        #if os(iOS)
        if hasMadePurchase {
            let ruleID = await MainActor.run { ApphudScreensManager.shared.pendingRule()?.id }
            if let ruleID {
                params["rule_id"] = ruleID
            }
        }
        #endif

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
                    ApphudScreensManager.shared.cacheActiveScreens()
                }
            }
        #endif

        let transactionId = params["transaction_id"] as? String

        self.requiresReceiptSubmission = true

        apphudLog("Uploading App Store Receipt...")

        // `lastUploadedTransactions` means "the backend acknowledged this transaction",
        // because it is what authorises finishing one (see handleTransaction and the
        // legacy queue twin). It is therefore recorded only after a successful upload.
        let recordUploadedTransaction: @MainActor () -> Void = {
            guard let transactionId, let trInt = UInt64(transactionId) else { return }
            guard !self.lastUploadedTransactions.contains(trInt) else { return }
            // Keep the list bounded: it is persisted and only used for recent dedup.
            self.lastUploadedTransactions = (self.lastUploadedTransactions + [trInt]).suffix(200)
        }

        httpClient?.startRequest(path: .subscriptions, params: params, method: .post, useDecoder: true, retry: (hasMadePurchase && !fallbackMode)) { (result, _, data, error, errorCode, duration, _) in
            Task { @MainActor in

                // Release the slot and take the callbacks in ONE synchronous step, before
                // any await: a submission starting in between would otherwise inherit
                // these callbacks and answer its caller with a foreign result.
                self.submittingTransaction = nil
                let pendingCallbacks = self.submitReceiptCallbacks
                self.submitReceiptCallbacks.removeAll()

                if !result && hasMadePurchase && self.fallbackMode {
                    self.requiresReceiptSubmission = true
                    self.scheduleSubmitReceiptRetry(error: error, code: errorCode)
                    let stubProductId = transactionProductIdentifier ?? (productInfo?["product_id"] as? String) ?? apphudProduct?.productId
                    let hasChanges = await self.stubPurchase(productId: stubProductId)
                    self.notifyAboutUpdates(hasChanges)
                    pendingCallbacks.forEach { $0?(error ?? ApphudError(message: "Failed to submit transaction in fallback mode")) }
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

                if result {
                    recordUploadedTransaction()
                    self.observerModePurchaseIdentifiers = nil
                    self.submitReceiptRetries = (0, 0)
                    self.requiresReceiptSubmission = false
                    let hasChanges = await self.parseUser(data: data)
                    if notifyDelegate {
                        self.notifyAboutUpdates(hasChanges)
                    }
                } else {
                    self.scheduleSubmitReceiptRetry(error: error, code: errorCode)
                }

                // A failure must answer with a guaranteed error — a nil error reads as
                // backend acknowledgement and authorizes finishing the transaction.
                let finalError = result ? error : (error ?? ApphudError(message: "Failed to submit transaction"))
                pendingCallbacks.forEach { $0?(finalError) }
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
    internal func purchase(productId: String, product: ApphudProduct?, validate: Bool, isPurchasing: Binding<Bool>? = nil, fromScreen: Bool, value: Double? = nil) async -> ApphudPurchaseResult {
        await withUnsafeContinuation { continuation in
            isPurchasing?.wrappedValue = true
            purchase(productId: productId, product: product, validate: validate, purchasingFromScreen: fromScreen, callback: { result in
                isPurchasing?.wrappedValue = false
                continuation.resume(returning: result)
            })
        }
    }

    @MainActor internal func purchase(productId: String, product: ApphudProduct?, validate: Bool, purchasingFromScreen: Bool, value: Double? = nil, callback: ((ApphudPurchaseResult) -> Void)?) {
        // All SDK-initiated purchases go through StoreKit 2.
        purchasingProduct = product
        let commitmentPlanPreferred = product?.isCommitmentPlanPreferred() ?? false
        Task { @MainActor in
            await self.purchaseAsync(apphudProduct: product, productId: productId, commitmentPlan: commitmentPlanPreferred, fromScreen: purchasingFromScreen, value: value, callback: callback)
        }
    }

    internal func purchasePromo(productId: String?, apphudProduct: ApphudProduct?, discountID: String, fromScreen: Bool, callback: ((ApphudPurchaseResult) -> Void)?) {

        guard let productId = productId ?? apphudProduct?.productId else {
            callback?(ApphudPurchaseResult(nil, nil, nil, ApphudError(message: "Could not sign offer id: \(discountID): unknown product identifier")))
            return
        }

        self.signPromoOffer(productID: productId, discountID: discountID) { signedOffer, _ in
            guard let signedOffer else {
                callback?(ApphudPurchaseResult(nil, nil, nil, ApphudError(message: "Could not sign offer id: \(discountID), product id: \(productId)")))
                return
            }

            Task { @MainActor in
                self.purchasingProduct = apphudProduct
                let option = Product.PurchaseOption.promotionalOffer(offerID: signedOffer.offerID,
                                                                     keyID: signedOffer.keyID,
                                                                     nonce: signedOffer.nonce,
                                                                     signature: signedOffer.signature,
                                                                     timestamp: signedOffer.timestamp)
                await self.purchaseAsync(apphudProduct: apphudProduct, productId: productId, commitmentPlan: false, fromScreen: fromScreen, extraOptions: [option], callback: callback)
            }
        }
    }

    // MARK: - Private purchase methods

    @MainActor
    private func purchaseAsync(apphudProduct: ApphudProduct?, productId: String?, commitmentPlan: Bool, fromScreen: Bool, value: Double? = nil, extraOptions: Set<Product.PurchaseOption> = [], callback: ((ApphudPurchaseResult) -> Void)?) async {
        var product = try? await apphudProduct?.product()
        if product == nil, let productId {
            product = try? await ApphudAsyncStoreKit.shared.fetchProduct(productId)
        }

        guard let product else {
            let message = "Unable to start payment because product identifier is invalid: [\([productId ?? ""])]"
            apphudLog(message, forceDisplay: true)
            callback?(ApphudPurchaseResult(nil, nil, nil, ApphudError(message: message)))
            return
        }

        if let v = value {
            ApphudStoreKitWrapper.shared.purchasingValue = ApphudCustomPurchaseValue(product.id, v)
        } else {
            ApphudStoreKitWrapper.shared.purchasingValue = nil
        }

        #if os(visionOS)
        // visionOS requires an explicit UIScene to confirm the purchase in.
        let activeScene = UIApplication.shared.connectedScenes.first(where: { $0.activationState == .foregroundActive })
            ?? UIApplication.shared.connectedScenes.first
        guard let scene = activeScene else {
            callback?(ApphudPurchaseResult(nil, nil, nil, ApphudError(message: "Failed to retrieve UIScene for purchase confirmation")))
            return
        }
        let result: ApphudAsyncPurchaseResult = await ApphudAsyncStoreKit.shared.purchase(product: product, scene: scene, apphudProduct: apphudProduct, fromScreen: fromScreen, extraOptions: extraOptions)
        #else
        let result: ApphudAsyncPurchaseResult = await ApphudAsyncStoreKit.shared.purchase(product: product, commitmentPlan: commitmentPlan, apphudProduct: apphudProduct, fromScreen: fromScreen, extraOptions: extraOptions)
        #endif
        let resultV2 = ApphudPurchaseResult(result.subscription, result.nonRenewingPurchase, nil, result.error, transactionV2: result.transaction)
        resultV2.isPending = result.isPending
        callback?(resultV2)
    }

    internal func willPurchaseProductFrom(paywallId: String, placementId: String?) {
        observerModePurchaseIdentifiers = (paywallId, placementId)
    }

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor internal func asyncPurchaseResult(product: Product, transaction: StoreKit.Transaction?, error: Error?, isPending: Bool = false) -> ApphudAsyncPurchaseResult {

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

        return ApphudAsyncPurchaseResult(subscription: subscription, nonRenewingPurchase: purchase, transaction: transaction, error: error, isPending: isPending)
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

    /// Signed promotional offer fields returned by the `/sign_offer` endpoint,
    /// shaped for `Product.PurchaseOption.promotionalOffer`.
    struct ApphudSignedPromoOffer {
        let offerID: String
        let keyID: String
        let nonce: UUID
        let signature: Data
        let timestamp: Int
    }

    private func signPromoOffer(productID: String, discountID: String, callback: ((ApphudSignedPromoOffer?, Error?) -> Void)?) {
        let params: [String: Any] = ["product_id": productID, "offer_id": discountID, "application_username": ApphudStoreKitWrapper.shared.appropriateApplicationUsername() ?? "", "device_id": currentDeviceID, "user_id": currentUserID ]
        httpClient?.startRequest(path: .signOffer, params: params, method: .post) { (result, dict, _, error, _, _, _) in
            if result, let responseDict = dict, let dataDict = responseDict["data"] as? [String: Any], let resultsDict = dataDict["results"] as? [String: Any] {

                let signatureData = resultsDict["data"] as? [String: Any]
                let uuid = UUID(uuidString: signatureData?["nonce"] as? String ?? "")
                let signatureString = signatureData?["signature"] as? String
                let timestamp = signatureData?["timestamp"] as? NSNumber
                let keyID = resultsDict["key_id"] as? String

                if let signatureString, let signature = Data(base64Encoded: signatureString), let uuid, let timestamp, let keyID {
                    let signedOffer = ApphudSignedPromoOffer(offerID: discountID, keyID: keyID, nonce: uuid, signature: signature, timestamp: timestamp.intValue)
                    callback?(signedOffer, nil)
                    return
                }
            }

            let error = ApphudError(message: "Could not sign promo offer id: \(discountID), product id: \(productID)")
            callback?(nil, error)
        }
    }
}
