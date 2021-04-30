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

    @objc internal func continueToFetchProducts() {
        if let productIDs = delegate?.apphudProductIdentifiers?(), productIDs.count > 0 {
            let products = productIDs.map { ApphudProduct(id: $0, name: $0, productId: $0, store: "iOS", skProduct: nil) }
            let group = ApphudGroup(id: "Untitled", name: "Untitled", products: products)
            continueWithProductGroups([group], errorCode: nil)
        } else {
            #warning("TODO: USE CACHED PRODUCTS IDS TO REQUEST STOREKIT PRODUCTS")
            getProductGroups { groups, _, code in
                self.continueWithProductGroups(groups, errorCode: code)
            }
        }
    }
    
    fileprivate func continueWithProductGroups(_ productGroups: [ApphudGroup]?, errorCode: Int?) {
        // perform even if productsGroupsMap is nil or empty
        self.performAllProductGroupsFetchedCallbacks()

        guard let groups = productGroups, groups.count > 0 else {
            let noInternetErrorCode = errorCode == NSURLErrorNotConnectedToInternet
            self.scheduleProductsFetchRetry(noInternetErrorCode)
            return
        }
        
        self.productGroups = groups
        cacheGroups(groups: groups)
        self.continueToFetchStoreKitProducts()
    }

    fileprivate func scheduleProductsFetchRetry(_ noInternetError: Bool) {
        guard httpClient.canRetry else {
            return
        }
        guard productsFetchRetriesCount < maxNumberOfProductsFetchRetries else {
            apphudLog("Reached max number of product fetch retries \(productsFetchRetriesCount). Exiting..", forceDisplay: true)
            return
        }
        
        let delay: TimeInterval

        if noInternetError {
            delay = 2.0
        } else {
            delay = 5.0
            userRegisterRetriesCount += 1
        }
        
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(continueToFetchProducts), object: nil)
        perform(#selector(continueToFetchProducts), with: nil, afterDelay: delay)
        apphudLog("No Product Identifiers found in Apphud. Probably you forgot to add products in Apphud Settings? Scheduled products fetch retry in \(delay) seconds.", forceDisplay: true)
    }

    internal func continueToFetchStoreKitProducts() {

        guard self.productGroups.count > 0 else {
            return
        }
        
        var productIDs = [String]()
        productGroups.forEach { group in
            productIDs.append(contentsOf: group.products.map { $0.productId })
        }
        
        ApphudStoreKitWrapper.shared.fetchProducts(identifiers: Set(productIDs)) { storeKitProducts in
            
            self.updateProductGroupsWithStoreKitProducts()
            ApphudInternal.shared.performAllStoreKitProductsFetchedCallbacks()
            NotificationCenter.default.post(name: Apphud.didFetchProductsNotification(), object: storeKitProducts)
            ApphudInternal.shared.delegate?.apphudDidFetchProducts?(self.allAvailableProducts)
            ApphudInternal.shared.delegate?.apphudDidFetchStoreKitProducts?(storeKitProducts)
            self.customProductsFetchedBlocks.forEach { block in block(storeKitProducts) }
            self.customProductsFetchedBlocks.removeAll()
            
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

    internal func refreshStoreKitProductsWithCallback(callback: (([SKProduct]) -> Void)?) {
        
        callback.map { self.customProductsFetchedBlocks.append($0) }

        if self.currentUser == nil {
            continueToRegisteringUser()
        } else if productGroups.count > 0 {
            continueToFetchStoreKitProducts()
        } else {
            continueToFetchProducts()
        }
    }
    
    private func getProductGroups(callback: @escaping ([ApphudGroup]?, Error?, Int?) -> Void) {
        httpClient.startRequest(path: "products", apiVersion: .APIV2, params: ["device_id": currentDeviceID], method: .get, useDecoder: true) { result, _, data, error, code in
            
            if let data = data {
                typealias ApphudArrayResponse = ApphudAPIDataResponse<ApphudAPIArrayResponse <ApphudGroup> >
                
                let jsonDecoder = JSONDecoder()
                jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
                
                do {
                    let response = try jsonDecoder.decode(ApphudArrayResponse.self, from: data)
                    let groups = response.data.results
                    apphudLog("groups: \(groups)")
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
    
    internal func getPaywalls(callback: @escaping ([ApphudPaywall]?, Error?) -> Void) {
        self.getPaywallsOnly { paywalls, error in
            self.performWhenStoreKitProductFetched {
                if let paywalls = paywalls {
                    self.updatePaywallsWithStoreKitProducts(paywalls: paywalls)
                }
                callback(paywalls, error)
            }
        }
    }
    
    private func getPaywallsOnly(callback: @escaping ([ApphudPaywall]?, Error?) -> Void) {
        
        #warning("TODO: use cache")
        
        httpClient.startRequest(path: "paywall_configs", apiVersion: .APIV2, params: ["device_id": currentDeviceID], method: .get, useDecoder: true) { result, _, data, error, code in
            
            if let data = data {
                typealias ApphudArrayResponse = ApphudAPIDataResponse<ApphudAPIArrayResponse <ApphudPaywall> >
                
                let jsonDecoder = JSONDecoder()
                jsonDecoder.keyDecodingStrategy = .convertFromSnakeCase
                
                do {
                    let response = try jsonDecoder.decode(ApphudArrayResponse.self, from: data)
                    let paywalls = response.data.results
                    apphudLog("groups: \(paywalls)")
                    callback(paywalls, nil)
                } catch {
                    apphudLog("Failed to decode paywalls with error: \(error)")
                    callback(nil, error)
                }
            } else {
                callback(nil, error)
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
    
    internal func updatePaywallsWithStoreKitProducts(paywalls: [ApphudPaywall]) {
        paywalls.forEach { paywall in
            paywall.products?.forEach({ product in
                product.skProduct = ApphudStoreKitWrapper.shared.products.first(where: { $0.productIdentifier == product.productId })
                product.paywallId = paywall.id
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
            apphudDataToUserDefaultsCache(data: data, key: "ApphudProductGroups")
        }
    }
    
    internal func cachedGroups() -> [ApphudGroup]? {
        if let data = apphudDataFromUserDefaultsCache(key: "ApphudProductGroups") {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let groups = try? decoder.decode([ApphudGroup].self, from: data) {
                return groups
            }
        }
        
        return nil
    }
    
    internal func cachePaywalls(groups: [ApphudPaywall]) {
        let encoder = JSONEncoder()
        encoder.keyEncodingStrategy = .convertToSnakeCase
        if let data = try? encoder.encode(groups) {
            apphudDataToUserDefaultsCache(data: data, key: "ApphudPaywalls")
        }
    }
    
    internal func cachedPaywalls() -> [ApphudPaywall]? {
        #warning("TODO: USE THIS")
        if let data = apphudDataFromUserDefaultsCache(key: "ApphudPaywalls") {
            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase
            if let groups = try? decoder.decode([ApphudPaywall].self, from: data) {
                return groups
            }
        }
        
        return nil
    }
}
