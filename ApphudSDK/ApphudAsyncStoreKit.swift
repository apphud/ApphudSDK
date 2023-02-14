//
//  ApphudAsyncStoreKit.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 27.01.2023.
//

import Foundation
import StoreKit

@available(iOS 15.0, *)
final class TransactionObserver {

    var updates: Task<Void, Never>?

    init() {
        updates = newTransactionListenerTask()
    }

    deinit {
        updates?.cancel()
    }

    private func newTransactionListenerTask() -> Task<Void, Never> {
        Task(priority: .background) {
            for await verificationResult in Transaction.updates {
                self.handle(updatedTransaction: verificationResult)
            }
        }
    }

    private func handle(updatedTransaction verificationResult: VerificationResult<Transaction>) {
        guard case .verified(let transaction) = verificationResult else {
            if case .unverified(let unsignedTransaction, _) = verificationResult {
                apphudLog("Received unverified transaction [\(unsignedTransaction.id), \(unsignedTransaction.productID)] from StoreKit2")
                ApphudInternal.shared.setNeedToCheckTransactions()
            }
            return
        }

        if !ApphudUtils.shared.storeKitObserverMode {
            Task {
                _ = await ApphudInternal.shared.handleTransaction(transaction)
                await transaction.finish()
            }
        } else {
            apphudLog("Received transaction [\(transaction.id), \(transaction.productID)] from StoreKit2")
            ApphudInternal.shared.setNeedToCheckTransactions()
        }
    }
}

@available(iOS 15.0, macOS 12.0, *)
internal class ApphudAsyncStoreKit {

    static let shared = ApphudAsyncStoreKit()
    var isPurchasing: Bool = false
    var products = Set<Product>()

    var transactionsListener = TransactionObserver()

    var productsLoaded = false

    func fetchProducts() async throws -> [Product] {
        let ids = await ApphudInternal.shared.fetchAllAvailableProductIDs()
        return try await fetchProducts(ids, isLoadingAllAvailable: true)
    }

    func fetchProduct(_ id: String) async throws -> Product? {
        try await fetchProducts([id], isLoadingAllAvailable: false).first
    }

    func fetchProducts(_ ids: Set<String>, isLoadingAllAvailable: Bool) async throws -> [Product] {
        do {
            let loadedProducts = try await Product.products(for: ids)
            if loadedProducts.count > 0 {
                apphudLog("Successfully fetched Products from the App Store:\n \(loadedProducts.map { $0.id })")
            }
            self.products.formUnion(loadedProducts)

            if isLoadingAllAvailable {
                self.productsLoaded = true
            }

            return loadedProducts
        } catch {
            apphudLog("Failed to request Products from the App Store with error: \(error)")
            throw error
        }
    }

    func purchase(product: Product, apphudProduct: ApphudProduct?) async -> ApphudAsyncPurchaseResult {
        self.isPurchasing = true
        var options = Set<Product.PurchaseOption>()
        if let uuidString = ApphudStoreKitWrapper.shared.appropriateApplicationUsername(), let uuid = UUID(uuidString: uuidString) {
            options.insert(.appAccountToken(uuid))
        }

        do {
            ApphudLoggerService.shared.paywallCheckoutInitiated(apphudProduct?.paywallId, product.id)
            self.isPurchasing = true
            let result = try await product.purchase(options: options)
            var transaction: Transaction?

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

            return ApphudInternal.shared.asyncPurchaseResult(product: product, transaction: transaction, error: nil)

        } catch {
            self.isPurchasing = false
            return ApphudInternal.shared.asyncPurchaseResult(product: product, transaction: nil, error: error)
        }
    }
}
