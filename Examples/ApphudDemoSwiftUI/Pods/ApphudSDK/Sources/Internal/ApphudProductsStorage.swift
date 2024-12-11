//
//  ApphudProductsStorage.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 20.10.2023.
//

import Foundation
import StoreKit

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
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

    // the code below only applies to single product requests
    // see: func fetchProduct(_ id: String, discardable: Bool = false) async throws -> Product?
    private var requestedProductIds = Set<String>()

    func request(_ id: String) {
        requestedProductIds.insert(id)
    }

    func isRequested(_ id: String) -> Bool {
        requestedProductIds.contains(id)
    }

    func finishRequest(_ id: String) {
        requestedProductIds.remove(id)
    }
}
