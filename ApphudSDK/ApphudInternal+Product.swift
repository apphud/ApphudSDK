//
//  ApphudInternal+Product.swift
//  apphud
//
//  Created by Renat on 01.07.2020.
//  Copyright © 2020 softeam. All rights reserved.
//

import Foundation
import StoreKit

extension ApphudInternal {

    @objc internal func continueToFetchProducts() {
        if let productIDs = delegate?.apphudProductIdentifiers?(), productIDs.count > 0 {
            var map = [String: String]()
            productIDs.forEach { id in map[id] = "Untitled" }
            continueWithProductsMap(map)
        } else {
            getProducts { map in  self.continueWithProductsMap(map) }
        }
    }
    
    fileprivate func continueWithProductsMap(_ productsGroupsMap: [String: String]?) {
        // perform even if productsGroupsMap is nil or empty
        self.performAllProductGroupsFetchedCallbacks()

        if productsGroupsMap?.keys.count ?? 0 > 0 {
            self.productsGroupsMap = productsGroupsMap
            apphudToUserDefaultsCache(dictionary: self.productsGroupsMap!, key: "productsGroupsMap")
        }

        if self.productsGroupsMap?.keys.count ?? 0 > 0 {
            self.continueToFetchStoreKitProducts()
        } else {
            self.scheduleProductsFetchRetry()
        }
    }

    fileprivate func scheduleProductsFetchRetry() {
        guard httpClient.canRetry else {
            return
        }
        guard productsFetchRetriesCount < maxNumberOfProductsFetchRetries else {
            apphudLog("Reached max number of product fetch retries \(productsFetchRetriesCount). Exiting..", forceDisplay: true)
            return
        }
        productsFetchRetriesCount += 1
        let delay: TimeInterval = TimeInterval(productsFetchRetriesCount * 5)
        perform(#selector(continueToFetchProducts), with: nil, afterDelay: delay)
        apphudLog("No Product Identifiers found in Apphud. Probably you forgot to add products in Apphud Settings? Scheduled products fetch retry in \(delay) seconds.", forceDisplay: true)
    }

    internal func continueToFetchStoreKitProducts() {

        guard self.productsGroupsMap?.keys.count ?? 0 > 0 else {
            return
        }
        ApphudStoreKitWrapper.shared.fetchProducts(identifiers: Set(self.productsGroupsMap!.keys)) { _ in
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

        ApphudStoreKitWrapper.shared.customProductsFetchedBlock = callback

        if self.currentUser == nil {
            continueToRegisteringUser()
        } else if let productIDs = self.productsGroupsMap?.keys, productIDs.count > 0 {
            continueToFetchStoreKitProducts()
        } else {
            continueToFetchProducts()
        }
    }

    private func getProducts(callback: @escaping (([String: String]?) -> Void)) {

        httpClient.startRequest(path: "products", params: nil, method: .get) { (result, response, _, _) in
            if result, let dataDict = response?["data"] as? [String: Any],
                let productsArray = dataDict["results"] as? [[String: Any]] {

                var map = [String: String]()

                for product in productsArray {
                    let productID = (product["product_id"] as? String) ?? ""
                    let groupID = (product["group_id"] as? String) ?? ""
                    map[productID] = groupID
                }
                callback(map)
            } else {
                callback(nil)
            }
        }
    }
}
