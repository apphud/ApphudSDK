//
//  ApphudProduct.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 29.04.2021.
//

import Foundation
import StoreKit

/**
 Apphud's wrapper around `SKProduct`.
 
 In-App Purchase must configured in App Store Connect and should be added to Apphud Dashboard > Product Hub > Products.
 `ApphudProduct` is Apphud's wrapper around StoreKit's `SKProduct`.
 
 - Note: For more information  - [Product Hub Documentation](https://docs.apphud.com/getting-started/product-hub/products)
 */

public class ApphudProduct: NSObject, Codable {

    /**
     Product identifier from App Store Connect.
     */
    @objc public internal(set) var productId: String

    /**
     Product name from Apphud Dashboard
     */
    @objc public internal(set) var name: String?

    /**
     Always `app_store` in iOS SDK.
     */
    @objc public internal(set) var store: String

    /**
     When paywalls are successfully loaded, skProduct model will always be present if App Store returned model for this product id. getPaywalls method will return callback only when StoreKit products are fetched and mapped with Apphud products.
     
     May be `nil` if product identifier is invalid, or product is not available in App Store Connect.
     */
    @objc public internal(set) var skProduct: SKProduct?

    /**
     Current product's paywall identifier, if available.
     */
    @objc public internal(set) var paywallIdentifier: String?

    // MARK: - Private

    internal var id: String?
    @objc public internal(set) var paywallId: String?

    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case store
        case productId
    }

    init(dictionary: [String: Any]) {
        self.id = dictionary["id"] as? String ?? ""
        self.name = dictionary["name"] as? String ?? ""
        self.productId = dictionary["product_id"] as? String ?? ""
        self.store = dictionary["store"] as? String ?? "app_store"
    }

    init(id: String?, name: String?, productId: String, store: String, skProduct: SKProduct?) {
        self.id = id
        self.name = name
        self.productId = productId
        self.store = store
        self.skProduct = skProduct
    }

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try? values.decode(String.self, forKey: .id)
        name = try? values.decode(String.self, forKey: .name)
        productId = try values.decode(String.self, forKey: .productId)
        store = try values.decode(String.self, forKey: .store)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try? container.encode(id, forKey: .id)
        try? container.encode(name, forKey: .name)
        try container.encode(store, forKey: .store)
        try container.encode(productId, forKey: .productId)
    }
}
