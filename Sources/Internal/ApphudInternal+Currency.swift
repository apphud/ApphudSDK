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

        Task {
            let result = await Storefront.current
            if let store = result, await currentUser?.currency?.countryCodeAlpha3 != store.countryCode {

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

    private func fetchCurrencyLegacy() async {

        let skProducts: [SKProduct] = ApphudStoreKitWrapper.shared.products

        if skProducts.isEmpty {
            let groups: [ApphudGroup]?
            if await permissionGroups != nil {
                groups = await permissionGroups
            } else {
                groups = await fetchPermissionGroups()
            }

            var productIds = [String]()

            groups?.forEach({ group in
                productIds.append(contentsOf: group.products.compactMap { $0.productId })
            })

            await continueToFetchStoreKitProducts(maxAttempts: APPHUD_DEFAULT_RETRIES)
        }

        let priceLocale = skProducts.first?.priceLocale

        guard let priceLocale = priceLocale else { return }
        #if os(visionOS)
        guard let countryCode = priceLocale.region?.identifier else { return }
        guard let currencyCode = priceLocale.currency?.identifier else { return }
        #else
        guard let countryCode = priceLocale.regionCode else { return }
        guard let currencyCode = priceLocale.currencyCode else { return }
        #endif
        guard await countryCode != currentUser?.currency?.countryCode else { return }
        guard await currencyCode != currentUser?.currency?.code else { return }

        storefrontCurrency = ApphudCurrency(countryCode: countryCode,
                                            code: currencyCode,
                                            storeId: nil,
                                            countryCodeAlpha3: nil)

        setNeedsToUpdateUser = true
    }
}
