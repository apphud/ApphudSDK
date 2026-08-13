//
//  ApphudAsyncStoreKit.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 27.01.2023.
//

import Foundation
import StoreKit
import SwiftUI

#if os(visionOS)
import UIKit
#endif

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
internal class ApphudAsyncStoreKit {

    static let shared = ApphudAsyncStoreKit()
    var isPurchasing: Bool = false
    var transactionsListener = ApphudAsyncTransactionObserver()
    var purchaseIntentsListener = ApphudPurchaseIntentsObserver()
    var productsLoaded = false

    /// Touching this method forces the lazy singleton (and both listeners) to start.
    func startObserving() {}

    private var productsStorage = ApphudProductsStorage()

    func products() async -> [Product] {
        let prs = await productsStorage.readProducts()
        return Array(prs)
    }

    func fetchProducts() async throws -> [Product] {
        let ids = await ApphudInternal.shared.fetchAllAvailableProductIDs()
        return try await fetchProducts(ids, isLoadingAllAvailable: true)
    }

    func fetchProductIfNeeded(_ id: String) async throws {
        _ = try await fetchProduct(id, discardable: true)
    }

    func fetchProduct(_ id: String, discardable: Bool = false) async throws -> Product? {

        if let product = await productsStorage.readProducts().first(where: { $0.id == id }) {
            return product
        }

        if await productsStorage.isRequested(id) && discardable {
            apphudLog("Product [\(id)] is already requested, skipping")
            return nil
        }

        do {
            await productsStorage.request(id)
            let products = try await fetchProducts([id], isLoadingAllAvailable: false)
            await productsStorage.finishRequest(id)
            return products.first
        } catch {
            await productsStorage.finishRequest(id)
            throw error
        }
    }

    func fetchProducts(_ ids: Set<String>, isLoadingAllAvailable: Bool) async throws -> [Product] {
        do {
            apphudLog("Requesting products from the App Store: \(ids)")
            let loadedProducts = try await Product.products(for: ids)
            if loadedProducts.count > 0 {
                apphudLog("Successfully fetched Products from the App Store:\n \(loadedProducts.map { $0.id })")
            }

            await productsStorage.append(loadedProducts)

            if isLoadingAllAvailable { productsLoaded = true }

            return loadedProducts
        } catch {
            apphudLog("Failed to request Products from the App Store with error: \(error)")
            throw error
        }
    }

    @MainActor
    internal func purchaseResult(product: Product, _ scene: Any? = nil, commitmentPlan: Bool, apphudProduct: ApphudProduct?, fromScreen: Bool = false, isPurchasing: Binding<Bool>? = nil, extraOptions: Set<Product.PurchaseOption> = []) async -> ApphudAsyncPurchaseResult {
        self.isPurchasing = true
        await productsStorage.append(product)
        isPurchasing?.wrappedValue = true

        var options = Set<Product.PurchaseOption>()
        options.formUnion(extraOptions)

        if #available(iOS 26.4, macOS 26.4, tvOS 26.4, watchOS 26.4, visionOS 26.4, *) {
            let isSupported = await product.isCommitmentPlanSupported()
            if commitmentPlan && isSupported {
                options.insert(.billingPlanType(.monthly))
            }
        }

        if let uuidString = ApphudStoreKitWrapper.shared.appropriateApplicationUsername(), let uuid = UUID(uuidString: uuidString) {
            options.insert(.appAccountToken(uuid))
        }

        do {

            ApphudLoggerService.shared.paywallCheckoutInitiated(apphudProduct: apphudProduct, productId: product.id, screenId: nil)
            apphudLog("Starting StoreKit2 purchase of \(product.id), options: \(options.count)", forceDisplay: true)
            #if os(iOS) || os(tvOS) || os(macOS) || os(watchOS)
            let result = try await product.purchase(options: options)
            #else
            let result = try await product.purchase(confirmIn: (scene as! UIScene), options: options)
            #endif
            apphudLog("StoreKit2 purchase returned for \(product.id)", forceDisplay: true)

            var transaction: StoreKit.Transaction?
            var transactionJws: String?
            var purchaseError: Error?
            var isPendingPurchase = false

            switch result {
            case .success(let verificationResult):
                switch verificationResult {
                case .verified(let trx):
                    transaction = trx
                    transactionJws = verificationResult.jwsRepresentation
                case .unverified(let trx, let verificationError):
                    // An unverified transaction is never submitted: it is left unfinished
                    // and re-checked, so StoreKit can redeliver a verified copy later.
                    apphudLog("Received unverified transaction [\(trx.id), \(trx.productID)] from StoreKit2: \(verificationError)", forceDisplay: true)
                    ApphudInternal.shared.setNeedToCheckTransactions()
                    purchaseError = ApphudError(message: "Transaction failed StoreKit verification: \(verificationError.localizedDescription)")
                }
            case .pending:
                isPendingPurchase = true
                apphudLog("Purchase of \(product.id) is pending (e.g. Ask to Buy)", forceDisplay: true)
            case .userCancelled:
                ApphudLoggerService.shared.paywallPaymentCancelled(paywallId: apphudProduct?.paywallId, placementId: apphudProduct?.placementId, product: product)
                purchaseError = StoreKitError.userCancelled
            default:
                apphudLog("Purchase of \(product.id) returned unknown result: \(result)", forceDisplay: true)
            }

            if let transaction {
                await Self.processTransaction(transaction, jws: transactionJws, fromScreen: fromScreen)
            }

            self.isPurchasing = false
            isPurchasing?.wrappedValue = false

            return ApphudInternal.shared.asyncPurchaseResult(product: product, transaction: transaction, error: purchaseError, isPending: isPendingPurchase)

        } catch {
            ApphudLoggerService.shared.paywallPaymentError(paywallId: apphudProduct?.paywallId, placementId: apphudProduct?.placementId, productId: product.id, error: error.apphudErrorMessage())

            self.isPurchasing = false
            isPurchasing?.wrappedValue = false
            return ApphudInternal.shared.asyncPurchaseResult(product: product, transaction: nil, error: error)
        }
    }

    /// Transactions currently being submitted by any path — the direct purchase call or
    /// the `Transaction.updates` listener, both of which receive the same transaction.
    /// The first path owns submitting and finishing it; the other one skips without
    /// finishing, so a failed submission still leaves the transaction for redelivery.
    @MainActor private static var processingTransactionIDs = Set<UInt64>()

    @MainActor
    fileprivate static func processTransaction(_ transaction: StoreKit.Transaction, jws: String?, fromScreen: Bool = false) async {

        guard !processingTransactionIDs.contains(transaction.id) else {
            apphudLog("Transaction \(transaction.id) is already being processed, skipping duplicate delivery", logLevel: .debug)
            return
        }

        processingTransactionIDs.insert(transaction.id)
        defer { processingTransactionIDs.remove(transaction.id) }

        // Finish only after the transaction is handled: an unfinished transaction is
        // redelivered by StoreKit on the next launch, so a submit that failed against
        // the backend keeps the transaction alive for a retry.
        let handled = await ApphudInternal.shared.handleTransaction(transaction, jws: jws, fromScreen: fromScreen)
        if handled {
            await transaction.finish()
        }
    }

    func fetchLatestTransaction() async -> VerificationResult<StoreKit.Transaction>? {
        var latestTransaction: VerificationResult<StoreKit.Transaction>?

        for await result in StoreKit.Transaction.all {
            if case .verified(let transaction) = result {
                if latestTransaction == nil || latestTransaction!.unsafePayloadValue.purchaseDate < transaction.purchaseDate {
                    latestTransaction = result
                }
            }
        }

        return latestTransaction
    }

    #if os(iOS) || os(tvOS) || os(macOS) || os(watchOS)
    @MainActor
    func purchase(product: Product, commitmentPlan: Bool = false, apphudProduct: ApphudProduct?, fromScreen: Bool = false, isPurchasing: Binding<Bool>? = nil, extraOptions: Set<Product.PurchaseOption> = []) async -> ApphudAsyncPurchaseResult {
        return await purchaseResult(product: product, commitmentPlan: commitmentPlan, apphudProduct: apphudProduct, fromScreen: fromScreen, isPurchasing: isPurchasing, extraOptions: extraOptions)
    }
    #else
    @MainActor
    func purchase(product: Product, scene: UIScene, apphudProduct: ApphudProduct?, fromScreen: Bool = false, isPurchasing: Binding<Bool>? = nil, extraOptions: Set<Product.PurchaseOption> = []) async -> ApphudAsyncPurchaseResult {
        return await purchaseResult(product: product, scene, commitmentPlan: false, apphudProduct: apphudProduct, fromScreen: fromScreen, isPurchasing: isPurchasing, extraOptions: extraOptions)
    }
    #endif
}

/// Listens to StoreKit 2 purchase intents: promoted in-app purchases started on the
/// App Store product page, and win-back offers (iOS 18+). Replaces the StoreKit 1
/// `paymentQueue(_:shouldAddStorePayment:for:)` handler — Apple forbids using both.
final class ApphudPurchaseIntentsObserver {

    var intentsTask: Task<Void, Never>?

    init() {
        // PurchaseIntent exists on iOS/iPadOS 16.4+, macCatalyst 16.4+ and macOS 14.4+ only.
        #if os(iOS) || os(macOS)
        guard #available(iOS 16.4, macOS 14.4, *) else { return }
        intentsTask = Task(priority: .background) {
            for await intent in PurchaseIntent.intents {
                await Self.handle(product: intent.product)
            }
        }
        #endif
    }

    deinit {
        intentsTask?.cancel()
    }

    @available(iOS 16.4, macOS 14.4, *)
    @MainActor
    private static func handle(product: Product) async {
        if let callback = ApphudInternal.shared.delegate?.apphudShouldStartAppStoreDirectPurchase(product: product) {
            ApphudInternal.shared.purchase(productId: product.id, product: nil, validate: true, purchasingFromScreen: false, callback: callback)
            return
        }

        // Bridge for delegates still implementing the legacy SKProduct-based method.
        let skProduct: SKProduct? = await withCheckedContinuation { continuation in
            ApphudStoreKitWrapper.shared.fetchProducts(productIds: [product.id]) { products in
                continuation.resume(returning: products?.first)
            }
        }

        if let skProduct, let callback = ApphudInternal.shared.delegate?.apphudShouldStartAppStoreDirectPurchase(skProduct) {
            ApphudInternal.shared.purchase(productId: product.id, product: nil, validate: true, purchasingFromScreen: false, callback: callback)
        }
    }
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class ApphudAsyncTransactionObserver {

    var updates: Task<Void, Never>?

    init() {
        updates = newTransactionListenerTask()
    }

    deinit {
        updates?.cancel()
    }

    private func newTransactionListenerTask() -> Task<Void, Never> {
        Task(priority: .background) {
            for await verificationResult in StoreKit.Transaction.updates {
                self.handle(updatedTransaction: verificationResult)
            }
        }
    }

    private func handle(updatedTransaction verificationResult: VerificationResult<StoreKit.Transaction>) {
        guard case .verified(let transaction) = verificationResult else {
            if case .unverified(let unsignedTransaction, _) = verificationResult {
                apphudLog("Received unverified transaction [\(unsignedTransaction.id), \(unsignedTransaction.productID)] from StoreKit2")
                ApphudInternal.shared.setNeedToCheckTransactions()
            }
            return
        }

        let jws = verificationResult.jwsRepresentation

        if !ApphudUtils.shared.storeKitObserverMode {
            Task { @MainActor in
                // Duplicate delivery of a transaction the direct purchase path is already
                // submitting is filtered inside processTransaction by transaction id.
                await ApphudAsyncStoreKit.processTransaction(transaction, jws: jws)
            }
        } else {
            apphudLog("Received transaction [\(transaction.id), \(transaction.productID)] from StoreKit2")
            Task { @MainActor in
                await ApphudInternal.shared.handleTransaction(transaction, jws: jws)
            }
        }
    }
}
