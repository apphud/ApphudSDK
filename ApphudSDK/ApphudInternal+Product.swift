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

    internal func continueToFetchProducts() {
        self.getProducts(callback: { (productsGroupsMap) in
            // perform even if productsGroupsMap is nil or empty
            self.performAllProductGroupsFetchedCallbacks()

            if productsGroupsMap?.keys.count ?? 0 > 0 {
                self.productsGroupsMap = productsGroupsMap
                apphudLog("Products groups fetched: \(self.productsGroupsMap as AnyObject)")
                apphudToUserDefaultsCache(dictionary: self.productsGroupsMap!, key: "productsGroupsMap")
            }
            // continue to fetch storekit products anyway
            self.continueToFetchStoreKitProducts()
        })
    }

    internal func continueToFetchStoreKitProducts() {

        guard self.productsGroupsMap?.keys.count ?? 0 > 0 else {
            return
        }
        ApphudStoreKitWrapper.shared.fetchProducts(identifiers: Set(self.productsGroupsMap!.keys)) { _ in
            self.continueToUpdateProductPricesIfNeeded()
        }
    }

    private func continueToUpdateProductPricesIfNeeded() {
        guard !didSubmitProductPrices else {return}
        let products = ApphudStoreKitWrapper.shared.products
        if products.count > 0 {
            self.updateUserCurrencyIfNeeded(priceLocale: products.first?.priceLocale)
            self.continueToUpdateProductsPrices(products: products)
            didSubmitProductPrices = true
        }
    }

    private func continueToUpdateProductsPrices(products: [SKProduct]) {
        self.submitProducts(products: products) { (_, _, _, _) in
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

    private func submitProducts(products: [SKProduct], callback: ApphudHTTPResponseCallback?) {
        var array = [[String: Any]]()
        for product in products {
            let productParams: [String: Any] = product.apphudSubmittableParameters()
            array.append(productParams)
        }

        let params = ["products": array] as [String: Any]

        httpClient.startRequest(path: "products", params: params, method: .put, callback: callback)
    }
}
