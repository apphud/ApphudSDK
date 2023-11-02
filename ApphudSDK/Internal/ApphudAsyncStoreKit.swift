//
//  ApphudAsyncStoreKit.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 27.01.2023.
//

import Foundation
import StoreKit
import SwiftUI

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
internal class ApphudAsyncStoreKit {

    static let shared = ApphudAsyncStoreKit()
    var isPurchasing: Bool = false
    var transactionsListener = ApphudAsyncTransactionObserver()
    var productsLoaded = false

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
    func purchase(product: Product, apphudProduct: ApphudProduct?, isPurchasing: Binding<Bool>? = nil) async -> ApphudAsyncPurchaseResult {
        self.isPurchasing = true
        await productsStorage.append(product)
        isPurchasing?.wrappedValue = true
        var options = Set<Product.PurchaseOption>()
        if let uuidString = ApphudStoreKitWrapper.shared.appropriateApplicationUsername(), let uuid = UUID(uuidString: uuidString) {
            options.insert(.appAccountToken(uuid))
        }

        do {
            ApphudLoggerService.shared.paywallCheckoutInitiated(apphudProduct?.paywallId, product.id)
            let result = try await product.purchase(options: options)
            var transaction: StoreKit.Transaction?

            switch result {
            case .success(.verified(let trx)):
                transaction = trx
            case .success(.unverified(let trx, _)):
                transaction = trx
            case .pending:
                break
            case .userCancelled:
                ApphudLoggerService.shared.paywallPaymentCancelled(apphudProduct?.paywallId, product: product)
                break
            default:
                break
            }

            if let tr = transaction {
                _ = await ApphudInternal.shared.handleTransaction(tr)
                await tr.finish()
            }

            self.isPurchasing = false
            isPurchasing?.wrappedValue = false

            return ApphudInternal.shared.asyncPurchaseResult(product: product, transaction: transaction, error: nil)

        } catch {
            self.isPurchasing = false
            isPurchasing?.wrappedValue = false
            return ApphudInternal.shared.asyncPurchaseResult(product: product, transaction: nil, error: error)
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

        if !ApphudUtils.shared.storeKitObserverMode {
            Task { @MainActor in
                _ = await ApphudInternal.shared.handleTransaction(transaction)
                await transaction.finish()
            }
        } else {
            apphudLog("Received transaction [\(transaction.id), \(transaction.productID)] from StoreKit2")
            Task { @MainActor in
                try? await ApphudAsyncStoreKit.shared.fetchProductIfNeeded(transaction.productID)
            }
            ApphudInternal.shared.setNeedToCheckTransactions()
        }
    }
}
