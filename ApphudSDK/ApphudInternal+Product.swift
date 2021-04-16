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
            var map = [String: String]()
            productIDs.forEach { id in map[id] = "Untitled" }
            continueWithProductsMap(map, errorCode: nil)
        } else {
            getProducts { map, code in  self.continueWithProductsMap(map, errorCode: code) }
        }
    }
    
    fileprivate func continueWithProductsMap(_ productsGroupsMap: [String: String]?, errorCode: Int?) {
        // perform even if productsGroupsMap is nil or empty
        self.performAllProductGroupsFetchedCallbacks()

        if productsGroupsMap?.keys.count ?? 0 > 0 {
            self.productsGroupsMap = productsGroupsMap
            apphudToUserDefaultsCache(dictionary: self.productsGroupsMap!, key: "productsGroupsMap")
        }

        if self.productsGroupsMap?.keys.count ?? 0 > 0 {
            self.continueToFetchStoreKitProducts()
        } else {
            let noInternetErrorCode = errorCode == NSURLErrorNotConnectedToInternet
            self.scheduleProductsFetchRetry(noInternetErrorCode)
        }
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

        callback.map{ ApphudStoreKitWrapper.shared.customProductsFetchedBlocks.append($0) }

        if self.currentUser == nil {
            continueToRegisteringUser()
        } else if let productIDs = self.productsGroupsMap?.keys, productIDs.count > 0 {
            continueToFetchStoreKitProducts()
        } else {
            continueToFetchProducts()
        }
    }

    private func getProducts(callback: @escaping (([String: String]?, Int) -> Void)) {

        httpClient.startRequest(path: "products", params: ["device_id": currentDeviceID], method: .get) { (result, response, _, code) in
            if result, let dataDict = response?["data"] as? [String: Any],
                let productsArray = dataDict["results"] as? [[String: Any]] {

                var map = [String: String]()

                for product in productsArray {
                    let productID = (product["product_id"] as? String) ?? ""
                    let groupID = (product["group_id"] as? String) ?? ""
                    map[productID] = groupID
                }
                callback(map, code)
            } else {
                callback(nil, code)
            }
        }
    }
}
