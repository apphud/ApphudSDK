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

/// Native restore preparation is separate from the account-scoped submission. The internal
/// provider parameter lets tests hold StoreKit I/O while exercising the real public restore flow.
internal struct ApphudRestoreData {
    let receiptString: String?
    let transaction: StoreKit.Transaction?
    let transactionJws: String?
}

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

    @MainActor internal func restorePurchases(prepare: (@MainActor () async -> ApphudRestoreData)? = nil,
                                             callback: @escaping (ApphudPurchaseResult) -> Void) {
        if !isIdentityV1, let context = userResponseContext() {
            let operationID = UUID()
            restoreOperationCallbacks[operationID] = { error in
                let current = self.isCurrentUserResponse(context)
                let result = ApphudPurchaseResult(current ? self.currentUser?.subscriptions.first { $0.isActive() } : nil,
                                                 current ? self.currentUser?.purchases.first { $0.isActive() } : nil,
                                                 nil, current ? error : ApphudError(message: "Restore canceled because the user changed"))
                result.isRestoreResult = true
                callback(result)
            }
            Task { @MainActor in
                let prepared: ApphudRestoreData
                if let prepare { prepared = await prepare() }
                else { prepared = await self.prepareStoreKit2Restore(context: context) }
                guard self.isCurrentUserResponse(context), self.restoreOperationCallbacks[operationID] != nil else {
                    self.finishVersion2Restore(operationID, error: ApphudError(message: "Restore canceled because the user changed"))
                    return
                }
                self.submitVersion2Restore(prepared, context: context, operationID: operationID)
            }
            return
        }
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
            self.submitReceiptRestore(transaction: nil, restore: true)
        }
    }

    /// Restore semantics (StoreKit 2): silently walk `Transaction.currentEntitlements`
    /// first; only when the device has no entitlements at all, call `AppStore.sync()`
    /// once (shows the system authentication sheet) and walk again.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    internal func restoreUsingStoreKit2() async {
        let prepared = await prepareStoreKit2Restore(context: nil)
        let receiptString = prepared.receiptString
        let transaction = prepared.transaction
        let jws = prepared.transactionJws

        if receiptString == nil && transaction == nil {
            let error = ApphudError(message: "Failed to restore purchases: neither entitlements nor App Store receipt found on device.")
            apphudLog(error.localizedDescription, forceDisplay: true)
            await MainActor.run {
                self.restorePurchasesCallback?(self.currentUser?.subscriptions, self.currentUser?.purchases, error)
                self.restorePurchasesCallback = nil
            }
            return
        }

        // Like the purchase path, never wait forever for a registration that will not
        // be retried (invalid API key / unauthorized): the restore call must return.
        performWhenUserRegistered(allowFailure: true) {
            guard self.currentUser != nil else {
                self.failRestoreWithoutRegisteredUser()
                return
            }
            Task {
                await self.submitReceipt(productInfo: nil,
                                         apphudProduct: nil,
                                         transactionIdentifier: transaction.map { String($0.id) },
                                         transactionProductIdentifier: transaction?.productID,
                                         transactionState: nil,
                                         receiptString: receiptString,
                                         transactionJws: jws,
                                         notifyDelegate: true,
                                         restore: true,
                                         fromScreen: false) { error in
                    Task { @MainActor in
                        self.restorePurchasesCallback?(self.currentUser?.subscriptions, self.currentUser?.purchases, error)
                        self.restorePurchasesCallback = nil
                    }
                }
            }
        }
    }

    private func prepareStoreKit2Restore(context: ApphudIdentityContext?) async -> ApphudRestoreData {

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
        if let context, !(await isCurrentUserResponse(context)) {
            return ApphudRestoreData(receiptString: nil, transaction: nil, transactionJws: nil)
        }

        // AppStore.sync() shows the system authentication sheet, so it is a last resort:
        // only when the device has neither entitlements nor an App Store receipt to
        // submit (master parity — the receipt path was always silent).
        if latest == nil && apphudReceiptDataString() == nil {
            apphudLog("No entitlements and no receipt on device, requesting AppStore.sync()..")
            do {
                try await AppStore.sync()
                if let context, !(await isCurrentUserResponse(context)) {
                    return ApphudRestoreData(receiptString: nil, transaction: nil, transactionJws: nil)
                }
                latest = await latestEntitlement()
            } catch {
                apphudLog("AppStore.sync() failed or was canceled by user: \(error)")
            }
        }

        if let context, !(await isCurrentUserResponse(context)) {
            return ApphudRestoreData(receiptString: nil, transaction: nil, transactionJws: nil)
        }
        let receiptString = await appStoreReceipt()
        let transaction = latest.map { $0.unsafePayloadValue }
        let jws = latest?.jwsRepresentation

        return ApphudRestoreData(receiptString: receiptString, transaction: transaction, transactionJws: jws)
    }

    @MainActor
    private func submitVersion2Restore(_ prepared: ApphudRestoreData, context: ApphudIdentityContext, operationID: UUID) {
        guard prepared.receiptString != nil || prepared.transaction != nil else {
            finishVersion2Restore(operationID, error: ApphudError(message: "Failed to restore purchases: neither entitlements nor App Store receipt found on device."))
            return
        }
        performWhenUserRegistered(allowFailure: true) {
            guard self.isCurrentUserResponse(context), self.restoreOperationCallbacks[operationID] != nil else {
                self.finishVersion2Restore(operationID, error: ApphudError(message: "Restore canceled because the user changed"))
                return
            }
            guard self.currentUser != nil else {
                self.finishVersion2Restore(operationID, error: ApphudError(message: "Cannot restore purchases because user is not registered"))
                return
            }
            Task { @MainActor in
                await self.submitReceipt(productInfo: nil, apphudProduct: nil,
                                         transactionIdentifier: prepared.transaction.map { String($0.id) },
                                         transactionProductIdentifier: prepared.transaction?.productID,
                                         transactionState: nil, receiptString: prepared.receiptString,
                                         transactionJws: prepared.transactionJws, notifyDelegate: true,
                                         restore: true, fromScreen: false, requestContext: context) { error in
                    Task { @MainActor in self.finishVersion2Restore(operationID, error: error) }
                }
            }
        }
    }

    @MainActor
    private func finishVersion2Restore(_ operationID: UUID, error: Error?) {
        restoreOperationCallbacks.removeValue(forKey: operationID)?(error)
    }

    @MainActor
    internal func cancelVersion2Restores(error: Error) {
        let callbacks = Array(restoreOperationCallbacks.values)
        restoreOperationCallbacks.removeAll()
        callbacks.forEach { $0(error) }
    }

    /// A restore cannot proceed without a registered user: report it instead of hanging.
    @MainActor private func failRestoreWithoutRegisteredUser() {
        let error = ApphudError(message: "Failed to restore purchases: user is not registered.")
        apphudLog(error.localizedDescription, forceDisplay: true)
        restorePurchasesCallback?(nil, nil, error)
        restorePurchasesCallback = nil
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
                    await handleTransaction(latestTransaction, jws: latestResult.jwsRepresentation, automatic: true)
                }
            }
        }
    }

    /// Compatibility wrapper over `handleTransactionResult`: `true` when the
    /// transaction needs no further delivery — the caller may finish it.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @discardableResult internal func handleTransaction(_ transaction: StoreKit.Transaction, jws: String? = nil, fromScreen: Bool = false, automatic: Bool = false) async -> Bool {
        await handleTransactionResult(transaction, jws: jws, fromScreen: fromScreen, automatic: automatic) == nil
    }

    /// An automatic path skips another account's transaction: it moves only with a restore.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor
    private func isAnotherAccountsTransaction(_ transaction: StoreKit.Transaction) -> Bool {
        isAnotherAccountsToken(transaction.appAccountToken)
    }

    /// Identity version 2 only: version 1 sends every purchase, as SDK 4.6 did.
    @MainActor
    internal func isAnotherAccountsToken(_ token: UUID?) -> Bool {
        guard !isIdentityV1 else { return false }
        return ApphudStoreKitWrapper.belongsToAnotherAccount(token, identity: identity,
                                                      purchaseUserTokens: ApphudStoreKitWrapper.purchaseUserTokens())
    }

    /// The legacy queue twin's StoreKit 2 transaction when it is another account's. Mostly the
    /// product's latest transaction; otherwise one from the history, which has no finished consumables.
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor
    internal func anotherAccountsTransaction(id: UInt64, productID: String) async -> StoreKit.Transaction? {
        if case .verified(let latest) = await StoreKit.Transaction.latest(for: productID), latest.id == id {
            return isAnotherAccountsTransaction(latest) ? latest : nil
        }
        for await result in StoreKit.Transaction.all {
            if case .verified(let transaction) = result, transaction.id == id {
                return isAnotherAccountsTransaction(transaction) ? transaction : nil
            }
        }
        return nil
    }

    /// Returns `nil` when the transaction needs no further delivery (already tracked,
    /// ineligible, or submitted successfully) — the caller may finish it. Returns the
    /// submission error when it failed or was skipped mid-flight, so an unfinished
    /// transaction gets redelivered by StoreKit and retried — and the purchase path
    /// can surface WHY the purchase is not confirmed (master parity: clients gating
    /// on `result.error` must see a failed submission).
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor
    internal func handleTransactionResult(_ transaction: StoreKit.Transaction, jws: String? = nil, fromScreen: Bool = false, automatic: Bool = false) async -> Error? {
        let context = userResponseContext()
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
            return ApphudError(message: "Transaction \(transactionId) is already being submitted")
        }

        // use original transaction id to compare if already tracked
        let alreadyTracked = await isAlreadyTracked(transactionId: transaction.originalID, productId: productID, purchaseDate: purchaseDate)
        guard isCurrentUserResponse(context) else { return ApphudError(message: "Transaction canceled because the user changed") }
        if alreadyTracked {
            apphudLog("This transaction already tracked by Apphud: \(transactionId), skipping", logLevel: .debug)
            return nil
        }

        let transactions = await self.lastUploadedTransactions
        if transactions.contains(transactionId) {
            return nil
        }

        // Another account's purchase waits unfinished for its owner, as the backend may not have it
        // yet. A later transaction of a subscription (a renewal, an upgrade) may be finished: the backend
        // knows the subscription by its original transaction.
        if automatic, isAnotherAccountsTransaction(transaction) {
            apphudLog("Transaction \(transactionId) belongs to another account, skipping", logLevel: .debug)
            return transaction.originalID == transactionId
                ? ApphudError(message: "Transaction \(transactionId) belongs to another account")
                : nil
        }

        let shouldSubmit: Bool
        switch transaction.productType {
        case .autoRenewable:
            // The device clock can be ahead of the signed expiration date. Submit even
            // apparently expired subscriptions; the backend determines their validity.
            shouldSubmit = expirationDate != nil && refundDate == nil && upgrade == false
        default:
            shouldSubmit = refundDate == nil
        }

        if shouldSubmit {
            apphudLog("found transaction with ID: \(transactionId), \(productID), purchase date: \(purchaseDate)", logLevel: .debug)

            // StoreKit 2 path: product metadata comes from the SK2 product cache,
            // no SKProductsRequest involved.
            let product = try? await ApphudAsyncStoreKit.shared.fetchProduct(productID)
            let receipt = await appStoreReceipt()
            guard isCurrentUserResponse(context) else { return ApphudError(message: "Transaction canceled because the user changed") }
            let isRecentlyPurchased: Bool = purchaseDate > transactionNow().addingTimeInterval(-3600)
            return await withUnsafeContinuation { continuation in
                // allowFailure: a block that waits for a registration which never succeeds
                // is never released, which would hang the purchase call awaiting it.
                performWhenUserRegistered(allowFailure: true) {

                    guard self.isCurrentUserResponse(context) else {
                        continuation.resume(returning: ApphudError(message: "Transaction canceled because the user changed"))
                        return
                    }
                    guard self.currentUser != nil else {
                        apphudLog("Cannot submit transaction \(transactionId) because user is not registered, will retry later", forceDisplay: true)
                        continuation.resume(returning: ApphudError(message: "Cannot submit transaction \(transactionId): user is not registered"))
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
                                                 fromScreen: fromScreen, requestContext: context) { error in
                            continuation.resume(returning: error)
                        }
                    }
                }
            }
        }
        return nil
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

    // Master-parity receipt sourcing: when the receipt is missing on device, refresh
    // it via SKReceiptRefreshRequest before submitting (the backend validates by
    // receipt until it learns JWS). Unlike master, a still-missing receipt does NOT
    // block the submission — transaction id and JWS ride along either way.
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
                submitReceiptRestore(transaction: nil, restore: false)
            }
        }
    }

    /// [restore]: only the restore someone asked for.
    @MainActor internal func submitReceiptRestore(transaction: SKPaymentTransaction?, restore: Bool) {

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

        // A user-initiated restore is waiting for an answer and, like the purchase path,
        // must not wait forever for a registration that will not be retried. An automatic
        // submission (a restored transaction from the payment queue) has nobody waiting:
        // it stays queued for a later registration, as before.
        let userInitiated = restorePurchasesCallback != nil
        performWhenUserRegistered(allowFailure: userInitiated) {
            guard self.currentUser != nil else {
                self.failRestoreWithoutRegisteredUser()
                return
            }

            self.submitReceipt(product: nil, apphudProduct: nil, transaction: transaction, receiptString: receiptString, notifyDelegate: true, restore: restore, fromScreen: false) { error in
                self.restorePurchasesCallback?(self.currentUser?.subscriptions, self.currentUser?.purchases, error)
                self.restorePurchasesCallback = nil
            }
        }
    }

    internal func submitReceipt(product: SKProduct?, apphudProduct: ApphudProduct?, transaction: SKPaymentTransaction?, receiptString: String?, notifyDelegate: Bool, eligibilityCheck: Bool = false, ownsTransaction: Bool = false, restore: Bool = false, fromScreen: Bool, callback: ApphudNSErrorCallback?) {

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
                                   restore: restore,
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

    /// Identity fields of `POST /v4/subscriptions`. Identity version 1: `device_id` and `user_id`, no
    /// `restore`, as SDK 4.6 sent them.
    internal func subscriptionIdentityParams(restore: Bool) -> [String: Any] {
        guard !isIdentityV1 else { return identityParams(includeUserID: true) }
        var params: [String: Any] = identityParams(includeUserID: true)
        params["restore"] = restore
        // The old SDK's device_id adopts its customer, until a registration has done it.
        if let legacyDeviceID = identityStore.registrationReport(for: identity).legacyDeviceID {
            params["legacy_device_id"] = legacyDeviceID
        }
        return params
    }

    @MainActor
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
                                // True only for the restore the user asked for: it moves a purchase
                                // another customer owns. Purchases and automatic checks send false.
                                restore: Bool = false,
                                fromScreen: Bool,
                                restoreContext: (generation: UUID, identity: ApphudIdentity)? = nil,
                                requestContext: ApphudIdentityContext? = nil,
                                callback: ApphudNSErrorCallback?) async {

        let requestContext = requestContext ?? userResponseContext()
        guard isCurrentUserResponse(requestContext) else {
            callback?(ApphudError(message: "Receipt canceled because the user changed"))
            return
        }
        let newClaim = transactionIdentifier ?? transactionProductIdentifier ?? (productInfo?["product_id"] as? String) ?? "Restoration"

        // A product fetch may finish after the other StoreKit path. Reuse only this
        // identity's completed acknowledgement of the exact transaction, never a restore.
        if !isIdentityV1, ownsTransaction, !restore,
           let id = transactionIdentifier.flatMap(UInt64.init), submittingTransaction != newClaim,
           observedTransactions.hasAcknowledgement(id, identity: identity) {
            callback?(nil)
            return
        }

        // A V2 restore cannot use a false upload's answer: it must send true itself.
        // Transaction-owning callers still only join an upload of their own transaction.
        let claim: @MainActor () -> (String?, Bool, UUID?, Bool, Bool) = {
            if let restoreContext,
               restoreContext.generation != self.receiptSessionGeneration || !restoreContext.identity.hasSameIDs(as: self.identity) {
                return (nil, false, nil, true, false)
            }
            let existing = self.submittingTransaction
            let sameIdentity = self.isIdentityV1 || self.submittingReceiptIdentity?.hasSameIDs(as: self.identity) == true
            let deferredRestore = !self.isIdentityV1 && restore && existing != nil && (!self.submittingReceiptRestore || !sameIdentity)
            if existing != nil && !sameIdentity && !deferredRestore {
                return (existing, false, self.submittingReceiptID, false, true)
            }
            if existing == nil {
                self.submittingTransaction = newClaim
                self.submittingReceiptRestore = restore
                self.submittingReceiptIdentity = self.isIdentityV1 ? nil : self.identity
                self.submittingReceiptID = self.isIdentityV1 ? nil : UUID()
            }

            if deferredRestore {
                let requestedIdentity = self.identity
                let generation = self.receiptSessionGeneration
                // This callback runs after the previous response has been processed, on either
                // success or failure. Logout invalidates it before draining callbacks.
                self.submitReceiptCallbacks.append { _ in
                    Task { @MainActor in
                        await self.submitReceipt(productInfo: productInfo, apphudProduct: apphudProduct,
                                                 transactionIdentifier: transactionIdentifier,
                                                 transactionProductIdentifier: transactionProductIdentifier,
                                                 transactionState: transactionState, receiptString: receiptString,
                                                 transactionJws: transactionJws, notifyDelegate: notifyDelegate,
                                                 eligibilityCheck: eligibilityCheck, ownsTransaction: ownsTransaction,
                                                 restore: restore, fromScreen: fromScreen,
                                                 restoreContext: (generation, requestedIdentity), requestContext: requestContext, callback: callback)
                    }
                }
            } else if let callback, existing == nil || !ownsTransaction || existing == newClaim {
                if eligibilityCheck || self.submitReceiptCallbacks.count > 0 {
                    self.submitReceiptCallbacks.append(callback)
                } else {
                    self.submitReceiptCallbacks = [callback]
                }
            }
            return (existing, deferredRestore, self.submittingReceiptID, false, false)
        }
        // V2 claims and snapshots request identity without yielding between them.
        let (inFlight, deferredRestore, submissionID, canceledRestore, incompatibleIdentity) = isIdentityV1
            ? await MainActor.run(body: claim) : claim()

        if canceledRestore {
            callback?(ApphudError(message: "Restore canceled because the user changed"))
            return
        }
        if incompatibleIdentity {
            setNeedToCheckTransactions()
            callback?(ApphudError(message: "Receipt upload belongs to another user; transaction will be retried"))
            return
        }
        if deferredRestore {
            apphudLog("Explicit restore will submit after the current receipt upload")
            return
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

        let sentIdentity = identity
        let environment = Apphud.isSandbox() ? ApphudEnvironment.sandbox.rawValue : ApphudEnvironment.production.rawValue

        var params = subscriptionIdentityParams(restore: restore)
        params["environment"] = environment
        params["observer_mode"] = ApphudUtils.shared.storeKitObserverMode

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

        // Logout may have run during product/screen awaits. It already answered this upload's
        // callbacks; do not send it after that boundary or answer them again.
        if let submissionID, self.submittingReceiptID != submissionID { return }
        guard isCurrentUserResponse(requestContext) else {
            self.takeReceiptCallbacks(submissionID: submissionID)?.forEach { $0?(ApphudError(message: "Receipt canceled because the user changed")) }
            return
        }
        httpClient?.startRequest(path: .subscriptions, params: params, method: .post, useDecoder: true, retry: (hasMadePurchase && !fallbackMode)) { (result, _, data, error, errorCode, duration, _) in
            Task { @MainActor in

                // A late response after logout must not drain a new session's upload.
                // Each release takes its callbacks atomically; a new upload cannot inherit them.
                if let submissionID, self.submittingReceiptID != submissionID { return }
                guard self.isCurrentUserResponse(requestContext) else {
                    self.takeReceiptCallbacks(submissionID: submissionID)?.forEach { $0?(ApphudError(message: "Receipt canceled because the user changed")) }
                    return
                }
                // V1 keeps its original release timing. V2 includes response parsing in
                // single-flight so a late SK1 twin joins the same completed result.
                let version1Callbacks = self.isIdentityV1 ? self.takeReceiptCallbacks(submissionID: submissionID) : nil

                if !result && hasMadePurchase && self.fallbackMode {
                    self.requiresReceiptSubmission = true
                    self.scheduleSubmitReceiptRetry(error: error, code: errorCode)
                    let stubProductId = transactionProductIdentifier ?? (productInfo?["product_id"] as? String) ?? apphudProduct?.productId
                    let hasChanges = await self.stubPurchase(productId: stubProductId)
                    self.notifyAboutUpdates(hasChanges)
                    let pendingCallbacks = version1Callbacks ?? self.takeReceiptCallbacks(submissionID: submissionID) ?? []
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
                    let hasChanges = await self.parseUser(data: data, context: requestContext)
                    if let submissionID, self.submittingReceiptID != submissionID { return }
                    guard self.isCurrentUserResponse(requestContext) else {
                        self.takeReceiptCallbacks(submissionID: submissionID)?.forEach { $0?(ApphudError(message: "Receipt canceled because the user changed")) }
                        return
                    }
                    if !self.isIdentityV1, let id = transactionId.flatMap(UInt64.init) {
                        self.observedTransactions.acknowledge(id, identity: sentIdentity)
                    }
                    if notifyDelegate {
                        self.notifyAboutUpdates(hasChanges)
                    }
                } else {
                    self.scheduleSubmitReceiptRetry(error: error, code: errorCode)
                }

                // A failure must answer with a guaranteed error — a nil error reads as
                // backend acknowledgement and authorizes finishing the transaction.
                let finalError = result ? error : (error ?? ApphudError(message: "Failed to submit transaction"))
                let pendingCallbacks = version1Callbacks ?? self.takeReceiptCallbacks(submissionID: submissionID) ?? []
                pendingCallbacks.forEach { $0?(finalError) }
            }
        }
    }

    @MainActor
    private func takeReceiptCallbacks(submissionID: UUID?) -> [ApphudNSErrorCallback?]? {
        if let submissionID, submittingReceiptID != submissionID { return nil }
        submittingTransaction = nil
        submittingReceiptID = nil
        submittingReceiptIdentity = nil
        submittingReceiptRestore = false
        let callbacks = submitReceiptCallbacks
        submitReceiptCallbacks.removeAll()
        return callbacks
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

        // Read once: the offer is signed for this token and the purchase must send the same one,
        // even if the user id or the payment queue swizzle changes while the offer is being signed.
        let appAccountToken = ApphudStoreKitWrapper.shared.appAccountToken()

        self.signPromoOffer(productID: productId, discountID: discountID, appAccountToken: appAccountToken) { signedOffer, _ in
            guard let signedOffer else {
                callback?(ApphudPurchaseResult(nil, nil, nil, ApphudError(message: "Could not sign offer id: \(discountID), product id: \(productId)")))
                return
            }

            Task { @MainActor in
                self.purchasingProduct = apphudProduct
                var options: Set<Product.PurchaseOption> = [.promotionalOffer(offerID: signedOffer.offerID,
                                                                              keyID: signedOffer.keyID,
                                                                              nonce: signedOffer.nonce,
                                                                              signature: signedOffer.signature,
                                                                              timestamp: signedOffer.timestamp)]
                if let appAccountToken {
                    options.insert(.appAccountToken(appAccountToken))
                    if !self.isIdentityV1 {
                        ApphudStoreKitWrapper.rememberPurchaseToken(appAccountToken, identity: self.identity)
                    }
                }
                await self.purchaseAsync(apphudProduct: apphudProduct, productId: productId, commitmentPlan: false, fromScreen: fromScreen, extraOptions: options, addsCurrentAppAccountToken: false, callback: callback)
            }
        }
    }

    // MARK: - Private purchase methods

    @MainActor
    private func purchaseAsync(apphudProduct: ApphudProduct?, productId: String?, commitmentPlan: Bool, fromScreen: Bool, value: Double? = nil, extraOptions: Set<Product.PurchaseOption> = [], addsCurrentAppAccountToken: Bool = true, callback: ((ApphudPurchaseResult) -> Void)?) async {
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
        let result: ApphudAsyncPurchaseResult = await ApphudAsyncStoreKit.shared.purchase(product: product, scene: scene, apphudProduct: apphudProduct, fromScreen: fromScreen, extraOptions: extraOptions, addsCurrentAppAccountToken: addsCurrentAppAccountToken)
        #else
        let result: ApphudAsyncPurchaseResult = await ApphudAsyncStoreKit.shared.purchase(product: product, commitmentPlan: commitmentPlan, apphudProduct: apphudProduct, fromScreen: fromScreen, extraOptions: extraOptions, addsCurrentAppAccountToken: addsCurrentAppAccountToken)
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

    @MainActor internal func purchaseResult(productId: String, transaction: SKPaymentTransaction?, error: Error?) -> ApphudPurchaseResult {

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

    /// Parameters of the `/sign_offer` request for a purchase that sends `appAccountToken`.
    /// Apple checks the signature against that token in lowercase, or against an empty string
    /// when the purchase sends no token.
    /// Identity version 1: the parameters SDK 4.6 sent.
    static func promoOfferSignParamsV1(productID: String, discountID: String, appAccountToken: UUID?, deviceID: String, userID: String) -> [String: Any] {
        ["product_id": productID, "offer_id": discountID, "application_username": appAccountToken?.uuidString.lowercased() ?? "", "device_id": deviceID, "user_id": userID]
    }

    static func promoOfferSignParams(productID: String, discountID: String, appAccountToken: UUID?, identity: ApphudIdentity) -> [String: Any] {
        var params: [String: Any] = identity.requestParams
        if let userID = identity.userID {
            params["user_id"] = userID
        }
        params["product_id"] = productID
        params["offer_id"] = discountID
        params["application_username"] = appAccountToken?.uuidString.lowercased() ?? ""
        return params
    }

    /// The `/sign_offer` parameters of the identity version this launch runs.
    internal func signOfferParams(productID: String, discountID: String, appAccountToken: UUID?) -> [String: Any] {
        isIdentityV1
            ? Self.promoOfferSignParamsV1(productID: productID, discountID: discountID, appAccountToken: appAccountToken,
                                          deviceID: currentDeviceID, userID: currentUserID)
            : Self.promoOfferSignParams(productID: productID, discountID: discountID, appAccountToken: appAccountToken,
                                        identity: identity)
    }

    private func signPromoOffer(productID: String, discountID: String, appAccountToken: UUID?, callback: ((ApphudSignedPromoOffer?, Error?) -> Void)?) {
        let params = signOfferParams(productID: productID, discountID: discountID, appAccountToken: appAccountToken)
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
