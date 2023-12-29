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
        } else {
            Task.detached {
                await self.fetchCurrencyLegacy()
            }
        }
    }

    @available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
    private func fetchStorefrontCurrency() async {
        await withCheckedContinuation { continuation in
            fetchCurrencyWithMaxTimeout {
                if !self.currencyTaskFinished {
                    self.currencyTaskFinished = true
                    continuation.resume()
                }
            }
        }
    }

    @available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
    private func fetchCurrencyWithMaxTimeout(_ completion: @escaping () -> Void) {

        Task { @MainActor in
            let result = await Storefront.current
            if let store = result, currentUser?.currency?.countryCodeAlpha3 != store.countryCode {
                storefrontCurrency = ApphudCurrency(countryCode: store.countryCode,
                                                    code: nil,
                                                    storeId: store.id,
                                                    countryCodeAlpha3: store.countryCode)
                setNeedsToUpdateUser = true
            }
            if !currencyTaskFinished {
                completion()
            }
        }

        // Task for the timeout
        Task {
            try? await Task.sleep(nanoseconds: 200_000_000) // 0.2 seconds
            if !currencyTaskFinished {
                completion()
            }
        }
    }

    @MainActor private func fetchCurrencyLegacy() async {

        var skProducts: [SKProduct] = ApphudStoreKitWrapper.shared.products

        if skProducts.isEmpty {
            let groups: [ApphudGroup]?
            if permissionGroups != nil {
                groups = permissionGroups
            } else {
                groups = await fetchPermissionGroups()
            }

            var productIds = [String]()

            groups?.forEach({ group in
                productIds.append(contentsOf: group.products.compactMap { $0.productId })
            })

            let result = await ApphudStoreKitWrapper.shared.fetchAllProducts(identifiers: Set(productIds))
            skProducts = result.0
            await handleDidFetchAllProducts(storeKitProducts: result.0, error: result.1)
        }

        let priceLocale = skProducts.first?.priceLocale

        guard let priceLocale = priceLocale else { return }
        guard let countryCode = priceLocale.regionCode else { return }
        guard let currencyCode = priceLocale.currencyCode else { return }
        guard countryCode != currentUser?.currency?.countryCode else { return }
        guard currencyCode != currentUser?.currency?.code else { return }

        storefrontCurrency = ApphudCurrency(countryCode: countryCode,
                                            code: currencyCode,
                                            storeId: nil,
                                            countryCodeAlpha3: nil)

        setNeedsToUpdateUser = true
    }
}
