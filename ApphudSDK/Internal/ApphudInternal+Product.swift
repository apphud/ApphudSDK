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

    @objc internal func refetchProducts() {
        continueToFetchProducts(needToUpdateProductGroups: true, fallbackProducts: nil)
    }

    @objc internal func continueToFetchProducts(needToUpdateProductGroups: Bool = true, fallbackProducts: [String]?) {

        if let productIDs = (fallbackProducts ?? delegate?.apphudProductIdentifiers()), productIDs.count > 0 {
            let products = productIDs.map { ApphudProduct(id: $0, name: $0, productId: $0, store: "app_store", skProduct: nil) }
            let group = ApphudGroup(id: "Untitled", name: "Untitled", products: products)
            continueWithProductGroups([group], errorCode: nil, writeToCache: false)
        } else {
            if !needToUpdateProductGroups || fallbackMode {
                apphudLog("Using cached product groups structure")
                self.continueWithProductGroups(productGroups, errorCode: nil, writeToCache: false)
            } else {
                getProductGroups { groups, _, code in
                    self.continueWithProductGroups(groups, errorCode: code, writeToCache: true)
                }
            }
        }
    }

    fileprivate func continueWithProductGroups(_ productGroups: [ApphudGroup]?, errorCode: Int?, writeToCache: Bool) {

        // perform even if productsGroupsMap is nil or empty
        self.performAllProductGroupsFetchedCallbacks()

        guard let groups = productGroups, groups.count > 0 else {
            let noInternetErrorCode = errorCode == NSURLErrorNotConnectedToInternet
            self.scheduleProductsFetchRetry(noInternetErrorCode, errorCode: errorCode ?? 0)
            return
        }

        self.productsFetchRetries = (0, 0)
        self.productGroups = groups

        if writeToCache {
            cacheGroups(groups: groups)
        }

        self.continueToFetchStoreKitProducts()
    }

    fileprivate func scheduleProductsFetchRetry(_ noInternetError: Bool, errorCode: Int) {
        guard httpClient != nil, httpClient!.canRetry else {
            return
        }
        guard productsFetchRetries.count < maxNumberOfProductsFetchRetries else {
            apphudLog("Reached max number of product fetch retries \(productsFetchRetries.count). Exiting..", forceDisplay: true)
            return
        }

        var delay: TimeInterval

        if noInternetError {
            delay = 1.0
        } else {
            delay = 1.0
            productsFetchRetries.count += 1
            productsFetchRetries.errorCode = errorCode
        }

        if fallbackMode {
            delay *= 3.0
        }

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(refetchProducts), object: nil)
        perform(#selector(refetchProducts), with: nil, afterDelay: delay)
        apphudLog("No Product Identifiers found in Apphud. Probably you forgot to add products in Apphud Settings? Scheduled products fetch retry in \(delay) seconds.", forceDisplay: true)
    }

    internal func fetchAllAvailableProductIDs() async -> Set<String> {
        await withCheckedContinuation({ continuation in
            performWhenProductGroupsFetched {
                continuation.resume(returning: self.allAvailableProductIDs())
            }
        })
    }

    internal func allAvailableProductIDs() -> Set<String> {
        var productIDs = [String]()
        productGroups.forEach { group in
            productIDs.append(contentsOf: group.products.map { $0.productId })
        }
        return Set(productIDs)
    }

    internal func continueToFetchStoreKitProducts() {

        guard self.productGroups.count > 0 else {
            return
        }

        ApphudStoreKitWrapper.shared.fetchProducts(identifiers: allAvailableProductIDs()) { storeKitProducts, error in

            self.updateProductGroupsWithStoreKitProducts()
            ApphudInternal.shared.performAllStoreKitProductsFetchedCallbacks()
            NotificationCenter.default.post(name: Apphud.didFetchProductsNotification(), object: storeKitProducts)
            ApphudInternal.shared.delegate?.apphudDidFetchStoreKitProducts(storeKitProducts, error)
            ApphudInternal.shared.delegate?.apphudDidFetchStoreKitProducts(storeKitProducts)
            self.customProductsFetchedBlocks.forEach { block in block(storeKitProducts, error) }
            self.customProductsFetchedBlocks.removeAll()
            self.updatePaywallsWithStoreKitProducts(paywalls: self.paywalls) // double call, but it's okay, because user may call refreshStorKitProducts method
            self.respondedStoreKitProducts = true
            self.continueToUpdateCurrencyIfNeeded()
        }
    }

    private func continueToUpdateCurrencyIfNeeded() {
        guard let locale = ApphudStoreKitWrapper.shared.products.first?.priceLocale else {
            return
        }

        self.performWhenUserRegistered {
            self.updateUserCurrencyIfNeeded(priceLocale: locale)
        }
    }

    internal func refreshStoreKitProductsWithCallback(callback: (([SKProduct], Error?) -> Void)?) {

        callback.map { self.customProductsFetchedBlocks.append($0) }

        if self.currentUser == nil {
            continueToRegisteringUser()
        } else if productGroups.count > 0 {
            continueToFetchStoreKitProducts()
        } else {
            continueToFetchProducts(fallbackProducts: nil)
        }
    }

    private func getProductGroups(callback: @escaping ([ApphudGroup]?, Error?, Int?) -> Void) {

        guard isInitialized else {
            apphudLog(ApphudInitializeGuardText, forceDisplay: true)
            return
        }

        httpClient?.startRequest(path: .products, apiVersion: .APIV2, params: ["observer_mode": ApphudUtils.shared.storeKitObserverMode, "device_id": currentDeviceID], method: .get, useDecoder: true) { _, _, data, error, code, duration in

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

    internal func preparePaywalls(pwls: [ApphudPaywall], writeToCache: Bool = true, completionBlock: (([ApphudPaywall]?, Error?) -> Void)?) {

        if UserDefaults.standard.bool(forKey: swizzlePaymentDisabledKey) != true && httpClient!.canSwizzlePayment() {
            ApphudStoreKitWrapper.shared.enableSwizzle()
        } else {
            apphudLog("Payment swizzle has been disabled remotely, skipping", logLevel: .debug)
        }

        self.paywalls = pwls

        if writeToCache { self.cachePaywalls(paywalls: paywalls) }

        if !didPreparePaywalls {
            delegate?.userDidLoad(rawPaywalls: paywalls)
            didPreparePaywalls = true
        }

        self.performWhenStoreKitProductFetched {
            self.updatePaywallsWithStoreKitProducts(paywalls: self.paywalls)
            completionBlock?(self.paywalls, nil)
            self.customPaywallsLoadedCallbacks.forEach { block in block(self.paywalls) }
            self.customPaywallsLoadedCallbacks.removeAll()
            self.delegate?.paywallsDidFullyLoad(paywalls: self.paywalls)
        }
    }
    private func fetchPaywallsIfNeeded(forceRefresh: Bool = false, callback: @escaping ([ApphudPaywall]?, Error?, Bool) -> Void) {

        guard paywalls.isEmpty || forceRefresh else {
            apphudLog("Using cached paywalls")
            callback(paywalls, nil, false)
            return
        }

        httpClient?.startRequest(path: .paywalls, apiVersion: .APIV2, params: ["device_id": currentDeviceID], method: .get, useDecoder: true) { _, _, data, error, _, _ in

            if let data = data {
                typealias ApphudArrayResponse = ApphudAPIDataResponse<ApphudAPIArrayResponse <ApphudPaywall> >

                let jsonDecoder = JSONDecoder()
                jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase

                do {
                    let response = try jsonDecoder.decode(ApphudArrayResponse.self, from: data)
                    let paywalls = response.data.results
                    callback(paywalls, nil, true)
                } catch {
                    apphudLog("Failed to decode paywalls with error: \(error)")
                    callback(nil, error, false)
                }
            } else {
                callback(nil, error, false)
            }
        }
    }

    // MARK: - Product Groups Helper Methods

    internal var allAvailableProducts: [ApphudProduct] {
        var products = [ApphudProduct]()
        productGroups.forEach { group in
            products.append(contentsOf: group.products)
        }
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

        if paywallsContainsProducts {return true}

        updatePaywallsWithStoreKitProducts(paywalls: paywalls)

        paywalls.forEach { paywall in
            paywall.products.forEach { p in
                if p.skProduct != nil {
                    paywallsContainsProducts = true
                }
            }
        }

        if respondedStoreKitProducts {
            return true
        }

        return paywallsContainsProducts
    }

    internal func updatePaywallsWithStoreKitProducts(paywalls: [ApphudPaywall]) {
        performWhenUserRegistered {
            self.paywallsLoadTime = Date().timeIntervalSince(self.initDate)
        }

        paywalls.forEach { paywall in
            paywall.products.forEach({ product in
                product.paywallId = paywall.id
                product.paywallIdentifier = paywall.identifier
                product.skProduct = ApphudStoreKitWrapper.shared.products.first(where: { $0.productIdentifier == product.productId })
            })
        }
    }

    internal func updateProductGroupsWithStoreKitProducts() {
        productGroups.forEach { group in
            group.products.forEach { product in
                product.skProduct = ApphudStoreKitWrapper.shared.products.first(where: { $0.productIdentifier == product.productId })
            }
        }
    }

    internal func groupID(productId: String) -> String? {

        for group in productGroups {
            let productIds = group.products.map { $0.productId }
            if productIds.contains(productId) {
                return group.id
            }
        }

        return nil
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
}
