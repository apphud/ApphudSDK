//
//  ApphudInternal+Fallback.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 01.09.2023.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

import StoreKit

extension ApphudInternal {

    func executeFallback() {

        guard !didPreparePaywalls else {
            apphudLog("No need for fallback", logLevel: .debug)
            return
        }

        guard let url = Bundle.main.url(forResource: "apphud_paywalls_fallback", withExtension: "json") else {
            apphudLog("Fallback JSON file not found", logLevel: .all)
            return
        }

        guard !fallbackMode else {
            apphudLog("Already in fallback mode")
            return
        }

        fallbackMode = true

        if self.currentUser == nil {
            self.currentUser = ApphudUser(userID: Apphud.userID())
            self.performAllUserRegisteredBlocks()
        }

        if self.paywalls.count > 0 && self.allAvailableProductIDs().count > 0 && self.productGroups.count > 0 {
            self.preparePaywalls(pwls: self.paywalls, writeToCache: false, completionBlock: nil)
            apphudLog("fallback mode with cached paywalls", logLevel: .all)
            return
        }

        do {
            let jsonData = try Data(contentsOf: url)

            typealias ApphudArrayResponse = ApphudAPIDataResponse<ApphudAPIArrayResponse <ApphudPaywall> >

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            let pwlsResponse = try decoder.decode(ApphudArrayResponse.self, from: jsonData)
            let pwls = pwlsResponse.data.results

            self.preparePaywalls(pwls: pwls, writeToCache: false, completionBlock: nil)

            var allProductIds = [String]()
            self.paywalls.forEach { p in
                allProductIds.append(contentsOf: p.products.map { $0.productId })
            }

            guard allProductIds.count > 0 else {
                apphudLog("No products in fallback paywalls", logLevel: .all)
                return
            }

            apphudLog("Fallback mode is active", logLevel: .all)
            continueToFetchProducts(fallbackProducts: allProductIds)

        } catch {
            apphudLog("Failed to parse fallback paywalls: \(error)")
        }
    }

    func stubPurchase(product: SKProduct?) -> HasPurchasesChanges {
        guard let product = product, !Apphud.hasPremiumAccess() else {
            apphudLog("No need to stub purchase because already has premium access")
            return HasPurchasesChanges(false, false)
        }

        if product.subscriptionGroupIdentifier != nil {
            let subscription = ApphudSubscription(product: product)
            self.currentUser = ApphudUser(userID: currentUserID, subscriptions: [subscription], paywalls: paywalls)

            apphudLog("Creating stub subscription with 1 hour expiration..")

            self.currentUser?.toCacheV2()

            return HasPurchasesChanges(true, false)
        } else {
            let purchase = ApphudNonRenewingPurchase(product: product)
            self.currentUser = ApphudUser(userID: currentUserID, purchases: [purchase], paywalls: paywalls)

            self.currentUser?.toCacheV2()

            return HasPurchasesChanges(false, true)
        }
    }
}
