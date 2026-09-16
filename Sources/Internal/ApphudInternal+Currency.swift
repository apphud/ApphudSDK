//
//  ApphudInternal+Currency.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 01.12.2023.
//

import Foundation
import StoreKit

extension ApphudInternal {
    internal func fetchCurrencyIfNeeded() async {
        if #available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *) {
            if await currentUser?.currency?.countryCodeAlpha3 != nil {
                Task.detached {
                    await self.fetchStorefrontCurrency()
                }
            } else {
                await fetchStorefrontCurrency()
            }
        }
    }

    @available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
    private func fetchStorefrontCurrency() async {
        await withUnsafeContinuation { continuation in
            fetchCurrencyWithMaxTimeout {
                continuation.resume()
            }
        }
    }

    @MainActor
    func canResumeFetchingCurrency() -> Bool {
        if !currencyTaskFinished {
            currencyTaskFinished = true
            return true
        } else {
            return false
        }
    }

    @available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
    private func fetchCurrencyWithMaxTimeout(_ completion: @escaping () -> Void) {

        Task {
            let result: Storefront? = await Storefront.current
            if let store = result, await currentUser?.currency?.countryCodeAlpha3 != store.countryCode {

                storefrontCurrency = ApphudCurrency(countryCode: store.countryCode,
                                                    code: nil,
                                                    storeId: store.id,
                                                    countryCodeAlpha3: store.countryCode)
                setNeedsToUpdateUser = true
            } else if result == nil {
                apphudLog("Failed to get Storefront, fetching currency from StoreKit products")
                Task.detached {
                    await self.fetchCurrencyFromProducts()
                }
            } else {
                apphudLog("Storefront currency didn't change, skipping")
            }
            if await canResumeFetchingCurrency() {
                completion()
            }
        }

        // Task for the timeout
        Task {
            try? await Task.sleep(nanoseconds: 300_000_000) // 0.3 seconds
            if await canResumeFetchingCurrency() {
                completion()
            }
        }
    }

    /// Fallback when `Storefront.current` is unavailable: derive the currency from
    /// a loaded StoreKit 2 product (price format style on iOS 16+, SK1 feeder below).
    @available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
    private func fetchCurrencyFromProducts() async {

        var products = await ApphudAsyncStoreKit.shared.products()

        if products.isEmpty {
            if await permissionGroups == nil {
                _ = await fetchPermissionGroups()
            }

            await continueToFetchStoreKitProducts(maxAttempts: APPHUD_DEFAULT_RETRIES)
            products = await withUnsafeContinuation { continuation in
                Task { @MainActor in
                    performWhenStoreKitProductFetched(maxAttempts: 3) { _ in
                        Task {
                            continuation.resume(returning: await ApphudAsyncStoreKit.shared.products())
                        }
                    }
                }
            }
        }

        guard let product = products.first else { return }
        guard let countryCode = product.apphudCountryCode() else { return }
        guard let currencyCode = product.apphudCurrencyCode() else { return }

        guard await countryCode != currentUser?.currency?.countryCode else { return }
        guard await currencyCode != currentUser?.currency?.code else { return }

        storefrontCurrency = ApphudCurrency(countryCode: countryCode,
                                            code: currencyCode,
                                            storeId: nil,
                                            countryCodeAlpha3: nil)

        setNeedsToUpdateUser = true
        apphudLog("Did prepare currency from products: \(countryCode)/\(currencyCode)")
    }
}
