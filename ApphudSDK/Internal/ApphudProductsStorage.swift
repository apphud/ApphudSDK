//
//  ApphudProductsStorage.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 20.10.2023.
//

import Foundation
import StoreKit

@available(iOS 15.0, *)
actor ApphudProductsStorage {

    private var products = Set<Product>()

    func append(_ element: Product) {
        products.insert(element)
    }

    func append(_ elements: [Product]) {
        products.formUnion(elements)
    }

    func readProducts() -> Set<Product> {
        products
    }
}
