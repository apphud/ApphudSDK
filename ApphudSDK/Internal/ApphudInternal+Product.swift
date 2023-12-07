//
//  ApphudInternal+Product.swift
//  apphud
//
//  Created by Renat on 01.07.2020.
//  Copyright © 2020 Apphud Inc. All rights reserved.
//

import Foundation
import StoreKit

extension ApphudInternal {

    internal func fetchAllAvailableProductIDs() async -> Set<String> {
        await withCheckedContinuation({ continuation in
            performWhenUserRegistered {
                continuation.resume(returning: self.allAvailableProductIDs())
            }
        })
    }

    internal func allAvailableProductIDs() -> Set<String> {
        var productIDs = [String]()

        paywalls.forEach { p in
            productIDs.append(contentsOf: p.products.map { $0.productId })
        }

        permissionGroups?.forEach({ group in
            productIDs.append(contentsOf: group.products.map { $0.productId })
        })

        return Set(productIDs)
    }

    internal func continueToFetchStoreKitProducts() async {

        let productIds = allAvailableProductIDs()

        guard productIds.count > 0 else {
            return
        }

        let result = await ApphudStoreKitWrapper.shared.fetchAllProducts(identifiers: productIds)
        await handleDidFetchAllProducts(storeKitProducts: result.0, error: result.1)
    }

    internal func handleDidFetchAllProducts(storeKitProducts: [SKProduct], error: Error?) async {
        await self.performAllStoreKitProductsFetchedCallbacks()
        await MainActor.run {
            self.updatePaywallsAndPlacements()
        }
        self.respondedStoreKitProducts = true
    }

    internal func refreshStoreKitProductsWithCallback(callback: (([SKProduct], Error?) -> Void)?) {
        Task(priority: .userInitiated) {

            if permissionGroups == nil {
                _ = await fetchPermissionGroups()
            }

            let availableIds = ApphudInternal.shared.allAvailableProductIDs()
            if availableIds.isEmpty {
                let msg = "None of the products have been added to any permission groups or paywalls."
                let error = ApphudError(message: msg)
                apphudLog(msg, forceDisplay: true)
                callback?([], error)
            } else {
                let result = await ApphudStoreKitWrapper.shared.fetchAllProducts(identifiers: availableIds)
                await handleDidFetchAllProducts(storeKitProducts: result.0, error: result.1)
                apphudPerformOnMainThread { callback?(result.0, result.1) }
            }
        }
    }

    internal func fetchPermissionGroups() async -> [ApphudGroup]? {
        await withCheckedContinuation { continuation in
            ApphudInternal.shared.getProductGroups { groups, _, _ in
                Task {
                    groups.map { self.cacheGroups(groups: $0) }
                }
                self.permissionGroups = groups
                continuation.resume(returning: groups)
            }
        }
    }

    private func getProductGroups(callback: @escaping ([ApphudGroup]?, Error?, Int?) -> Void) {

        guard isInitialized else {
            apphudLog(ApphudInitializeGuardText, forceDisplay: true)
            return
        }

        httpClient?.startRequest(path: .products, apiVersion: .APIV3, params: ["observer_mode": ApphudUtils.shared.storeKitObserverMode, "device_id": currentDeviceID], method: .get, useDecoder: true) { _, _, data, error, code, duration in

            if error == nil {
                ApphudLoggerService.shared.add(key: .products, value: duration, retryLog: self.productsFetchRetries)
            }

            if let data = data {
                typealias ApphudArrayResponse = ApphudAPIDataResponse<ApphudAPIArrayResponse <ApphudGroup> >

                let jsonDecoder = JSONDecoder()
                jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase

                do {
                    let response = try jsonDecoder.decode(ApphudArrayResponse.self, from: data)
                    let groups = response.data.results
                    callback(groups, nil, code)
                } catch {
                    apphudLog("Failed to decode products structure with error: \(error)")
                    callback(nil, error, code)
                }
            } else {
                callback(nil, error, code)
            }
        }
    }

    @MainActor internal func preparePaywalls(pwls: [ApphudPaywall], writeToCache: Bool = true, completionBlock: (([ApphudPaywall]?, Error?) -> Void)?) {

        if UserDefaults.standard.bool(forKey: swizzlePaymentDisabledKey) != true && httpClient!.canSwizzlePayment() {
            ApphudStoreKitWrapper.shared.enableSwizzle()
        } else {
            apphudLog("Payment swizzle has been disabled remotely, skipping", logLevel: .debug)
        }

        self.paywalls = pwls
        currentUser?.placements.map { self.placements = $0 }
        updatePaywallsAndPlacements()

        if writeToCache {
            Task.detached(priority: .utility) {
                self.cachePaywalls(paywalls: self.paywalls)
                self.cachePlacements(placements: self.placements)
            }
        }

        if !didPreparePaywalls {
            Task.detached { @MainActor in
                self.delegate?.userDidLoad(rawPaywalls: self.paywalls, rawPlacements: self.placements)
            }
            didPreparePaywalls = true
        }

        if !ApphudStoreKitWrapper.shared.didFetch {
            Task.detached {
                await self.continueToFetchStoreKitProducts()
            }
        }

        self.performWhenStoreKitProductFetched {
            self.updatePaywallsAndPlacements()
            completionBlock?(self.paywalls, nil)
            self.customPaywallsLoadedCallbacks.forEach { block in block(self.paywalls) }
            self.customPaywallsLoadedCallbacks.removeAll()
            self.delegate?.paywallsDidFullyLoad(paywalls: self.paywalls)
            self.delegate?.placementsDidFullyLoad(placements: self.placements)
        }
    }

    // MARK: - Product Groups Helper Methods

    internal var allAvailableProducts: [ApphudProduct] {

        var products = [ApphudProduct]()

        placements.forEach({ placement in
            placement.paywall.map { products.append(contentsOf: $0.products) }
        })

        paywalls.forEach { paywall in
            products.append(contentsOf: paywall.products)
        }

        permissionGroups?.forEach({ group in
            products.append(contentsOf: group.products)
        })

        return products
    }

    internal func paywallsAreReady() -> Bool {
        var paywallsContainsProducts = false
        paywalls.forEach { paywall in
            paywall.products.forEach { p in
                if p.skProduct != nil {
                    paywallsContainsProducts = true
                }
            }
        }

        return respondedStoreKitProducts || paywallsContainsProducts
    }

    @MainActor
    internal func updatePaywallsAndPlacements() {
        performWhenUserRegistered {
            self.paywallsLoadTime = Date().timeIntervalSince(self.initDate)
        }

        paywalls.forEach { paywall in
            paywall.update()
        }

        placements.forEach { placement in
            placement.paywall?.update(placementId: placement.id)
        }

        apphudLog("Did update Paywalls and Placements, has StoreKit Products: \(ApphudStoreKitWrapper.shared.products.count > 0)")
    }

    internal func cachePaywalls(paywalls: [ApphudPaywall]) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        if let data = try? encoder.encode(paywalls) {
            apphudDataToCache(data: data, key: "ApphudPaywalls")
        }
    }

    internal func cachedPaywalls() -> (objects: [ApphudPaywall]?, expired: Bool) {
        let dataFromCache = apphudDataFromCache(key: "ApphudPaywalls", cacheTimeout: cacheTimeout)
        if let data = dataFromCache.objectsData {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let paywalls = try? decoder.decode([ApphudPaywall].self, from: data) {
                return (paywalls, dataFromCache.expired)
            }
        }

        return (nil, true)
    }

    internal func cacheGroups(groups: [ApphudGroup]) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        if let data = try? encoder.encode(groups) {
            apphudDataToCache(data: data, key: "ApphudProductGroups")
        }
    }

    internal func cachedGroups() -> (objects: [ApphudGroup]?, expired: Bool) {

        let dataFromCache = apphudDataFromCache(key: "ApphudProductGroups", cacheTimeout: cacheTimeout)
        if let data = dataFromCache.objectsData {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let groups = try? decoder.decode([ApphudGroup].self, from: data) {
                return (groups, dataFromCache.expired)
            }
        }

        return (nil, true)
    }

    internal func cachePlacements(placements: [ApphudPlacement]) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        if let data = try? encoder.encode(placements) {
            apphudDataToCache(data: data, key: "ApphudPlacements")
        }
    }

    internal func cachedPlacements() -> (objects: [ApphudPlacement]?, expired: Bool) {
        let dataFromCache = apphudDataFromCache(key: "ApphudPlacements", cacheTimeout: cacheTimeout)
        if let data = dataFromCache.objectsData {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let placements = try? decoder.decode([ApphudPlacement].self, from: data) {
                return (placements, dataFromCache.expired)
            }
        }

        return (nil, true)
    }
}
