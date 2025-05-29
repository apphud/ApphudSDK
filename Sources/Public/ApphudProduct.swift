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
 
 - Note: For more information  - [Product Hub Documentation](https://docs.apphud.com/docs/product-hub)
 */

public class ApphudProduct: NSObject, Codable, ObservableObject {

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
    @Published @objc public internal(set) var skProduct: SKProduct? {
        willSet {
            objectWillChange.send()
        }
    }

    /**
    Returns Product struct for given Product Id. Makes async request to Apple, if not yet fetched. Or returns immediately, if available. Throwable.
     */
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    @MainActor public func product() async throws -> Product? {
        try await ApphudAsyncStoreKit.shared.fetchProduct(productId)
    }

    /**
     Current product's paywall identifier, if available.
     */
    @objc public internal(set) var paywallIdentifier: String?
    public internal(set) var properties: [String: ApphudAnyCodable]?
    @objc public internal(set) var paywallId: String?
    @objc public internal(set) var placementId: String?
    @objc public internal(set) var placementIdentifier: String?
    @objc public internal(set) var variationIdentifier: String?
    @objc public internal(set) var experimentId: String?
    
    // MARK: - Private
    internal var id: String?
    internal var itemId: String?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case itemId
        case name
        case store
        case productId
        case placementId
        case properties
    }

    init(id: String?, itemId: String?, name: String?, properties: [String: ApphudAnyCodable], productId: String, store: String, skProduct: SKProduct?) {
        self.id = id
        self.name = name
        self.productId = productId
        self.store = store
        self.skProduct = skProduct
        self.properties = properties
    }

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try? values.decode(String.self, forKey: .id)
        itemId = try? values.decode(String.self, forKey: .itemId)
        name = try? values.decode(String.self, forKey: .name)
        productId = try values.decode(String.self, forKey: .productId)
        store = try values.decode(String.self, forKey: .store)
        properties = try? values.decode([String: ApphudAnyCodable].self, forKey: .properties)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try? container.encode(id, forKey: .id)
        try? container.encode(itemId, forKey: .itemId)
        try? container.encode(name, forKey: .name)
        try container.encode(store, forKey: .store)
        try container.encode(productId, forKey: .productId)
        try? container.encode(properties, forKey: .properties)
    }
    
    internal func jsonProperties() -> [String: Any] {
        let langCode = Locale.current.languageCode ?? "en"
        var innerProps: ApphudAnyCodable?
        if let props = properties {
            if props[langCode] != nil {
                innerProps = props[langCode]
            } else {
                innerProps = props["en"]
            }
        }
        
        if let innerProps = innerProps?.value as? [String: ApphudAnyCodable] {
            let jsonProps = innerProps.mapValues { $0.toJSONValue() }
            return jsonProps
        } else {
            return [:]
        }
    }
}
