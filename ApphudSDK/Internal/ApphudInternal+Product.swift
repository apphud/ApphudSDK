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

    /// Returns false if products groups map dictionary not yet received, block is added to array and will be performed later.
    @MainActor internal func performWhenStoreKitProductFetched(callback : @escaping ApphudErrorCallback) {
        switch ApphudStoreKitWrapper.shared.status {
        case .none:
            self.storeKitProductsFetchedCallbacks.append(callback)
            Task(priority: .userInitiated) {
                await self.continueToFetchStoreKitProducts()
            }
        case .loading:
            self.storeKitProductsFetchedCallbacks.append(callback)
        case .fetched:
            DispatchQueue.main.async {
                callback(nil)
            }
        case .error(let error):
            if self.allAvailableProductIDs().count > 0 {
                self.storeKitProductsFetchedCallbacks.append(callback)
                // has Apphud products but storekit products loading failed, retry
                Task {
                    await self.continueToFetchStoreKitProducts()
                }
            } else {
                // no paywalls added in Product Hub, or they don't contain any products. Do nothing.
                callback(error)
            }
        }
    }

    @MainActor
    internal func performAllStoreKitProductsFetchedCallbacks(error: Error?) {
        for block in self.storeKitProductsFetchedCallbacks {
            apphudLog("Performing scheduled block..")
            block(error)
        }
        if self.storeKitProductsFetchedCallbacks.count > 0 {
            apphudLog("All scheduled blocks performed, removing..")
            self.storeKitProductsFetchedCallbacks.removeAll()
        }
    }
    
    internal func fetchAllAvailableProductIDs() async -> Set<String> {
        await withCheckedContinuation({ continuation in
            performWhenUserRegistered { @MainActor in
                continuation.resume(returning: self.allAvailableProductIDs())
            }
        })
    }

    @MainActor internal func allAvailableProductIDs() -> Set<String> {
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

        let productIds = await allAvailableProductIDs()

        guard productIds.count > 0 else {
            return
        }
        
        if case .loading = ApphudStoreKitWrapper.shared.status {
            return
        }

        let result = await ApphudStoreKitWrapper.shared.fetchAllProducts(identifiers: productIds)
        await handleDidFetchAllProducts(storeKitProducts: result.0, error: result.1)
    }

    internal func handleDidFetchAllProducts(storeKitProducts: [SKProduct], error: Error?) async {
        await MainActor.run {
            self.updatePaywallsAndPlacements()
        }
        await self.performAllStoreKitProductsFetchedCallbacks(error: error)
        self.respondedStoreKitProducts = true
    }

    internal func refreshStoreKitProductsWithCallback(callback: (([SKProduct], Error?) -> Void)?) {
        Task(priority: .userInitiated) {

            if await permissionGroups == nil {
                _ = await fetchPermissionGroups()
            }

            let availableIds = await ApphudInternal.shared.allAvailableProductIDs()
            if availableIds.isEmpty {
                let msg = "None of the products have been added to any permission groups or paywalls."
                let error = ApphudError(message: msg)
                apphudLog(msg, forceDisplay: true)
                apphudPerformOnMainThread {
                    callback?([], error)
                }
            } else {
                Task { @MainActor in
                    self.performWhenStoreKitProductFetched { error in
                        apphudPerformOnMainThread { callback?(ApphudStoreKitWrapper.shared.products, error) }
                    }
                }
            }
        }
    }

    internal func fetchPermissionGroups() async -> [ApphudGroup]? {
        await withCheckedContinuation { continuation in
            ApphudInternal.shared.getProductGroups { groups, _, _ in
                Task {
                    if let g = groups {
                        await self.cacheGroups(groups: g)
                        await MainActor.run { self.permissionGroups = groups }
                    }
                    continuation.resume(returning: groups)
                }
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
                await self.cachePaywalls(paywalls: self.paywalls)
                await self.cachePlacements(placements: self.placements)
            }
        }

        if !didPreparePaywalls {
            Task.detached { @MainActor in
                self.currentUser.map {
                    self.delegate?.userDidLoad(user: $0)
                }
            }
            didPreparePaywalls = true
        }

        self.performWhenStoreKitProductFetched { error in
            self.updatePaywallsAndPlacements()
            completionBlock?(self.paywalls, nil)
            self.delegate?.paywallsDidFullyLoad(paywalls: self.paywalls)
            self.delegate?.placementsDidFullyLoad(placements: self.placements)
        }
    }

    @MainActor
    internal func fetchOfferingsFull(callback: @escaping (Error?) -> Void) {
        performWhenUserRegistered {
            self.performWhenStoreKitProductFetched { error in
                callback(error)
            }
        }
    }

    // MARK: - Product Groups Helper Methods

    @MainActor internal var allAvailableProducts: [ApphudProduct] {

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

    @MainActor internal func paywallsAreReady() -> Bool {
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
            paywall.update(placementId: nil, placementIdentifier: nil)
        }

        placements.forEach { placement in
            placement.paywall?.update(placementId: placement.id, placementIdentifier: placement.identifier)
        }
    }

    internal func cachePaywalls(paywalls: [ApphudPaywall]) async {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        if let data = try? encoder.encode(paywalls) {
            await ApphudDataActor.shared.apphudDataToCache(data: data, key: "ApphudPaywalls")
        }
    }

    internal func cachedPaywalls() async -> (objects: [ApphudPaywall]?, expired: Bool) {
        let dataFromCache = await ApphudDataActor.shared.apphudDataFromCache(key: "ApphudPaywalls", cacheTimeout: cacheTimeout)
        if let data = dataFromCache.objectsData {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let paywalls = try? decoder.decode([ApphudPaywall].self, from: data) {
                return (paywalls, dataFromCache.expired)
            }
        }

        return (nil, true)
    }

    internal func cacheGroups(groups: [ApphudGroup]) async {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        if let data = try? encoder.encode(groups) {
            await ApphudDataActor.shared.apphudDataToCache(data: data, key: "ApphudProductGroups")
        }
    }

    internal func cachedGroups() async -> (objects: [ApphudGroup]?, expired: Bool) {
        let dataFromCache = await ApphudDataActor.shared.apphudDataFromCache(key: "ApphudProductGroups", cacheTimeout: cacheTimeout)
        if let data = dataFromCache.objectsData {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let groups = try? decoder.decode([ApphudGroup].self, from: data) {
                return (groups, dataFromCache.expired)
            }
        }

        return (nil, true)
    }

    internal func cachePlacements(placements: [ApphudPlacement]) async {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        if let data = try? encoder.encode(placements) {
            await ApphudDataActor.shared.apphudDataToCache(data: data, key: "ApphudPlacements")
        }
    }

    internal func cachedPlacements() async -> (objects: [ApphudPlacement]?, expired: Bool) {
        let dataFromCache = await ApphudDataActor.shared.apphudDataFromCache(key: "ApphudPlacements", cacheTimeout: cacheTimeout)
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
