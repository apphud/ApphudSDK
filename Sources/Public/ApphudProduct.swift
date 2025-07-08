//
//  ApphudProduct.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 29.04.2021.
//

import Foundation
import StoreKit

@available(iOS 15.0, *)
public enum ApphudProductType: String {
    case consumable
    case nonConsumable
    case autoRenewable
    case nonRenewable

    static func from(_ type: Product.ProductType) -> ApphudProductType? {
        switch type {
        case .autoRenewable: return .autoRenewable
        case .nonRenewable: return .nonRenewable
        case .consumable: return .consumable
        case .nonConsumable: return .nonConsumable
        default: return nil
        }
    }
}

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
     Returns product macros defined in the Paywalls section of Product Hub.

     By default, values are extracted based on the device's current locale.
     
     - Parameter locale: The language code to use for localization. Defaults to the device's locale.
     - Returns: A dictionary of localized macro values.
     */
    public func macroValues(locale: String = Locale.current.apphudLanguageCode()) async -> [String: any Sendable]? {
        await paywall?.renderPropertiesIfNeeded()

        return jsonProperties(langCode: locale, fallback: false)
    }

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
    @objc public internal(set) var paywallId: String?
    @objc public internal(set) var placementId: String?
    @objc public internal(set) var placementIdentifier: String?
    @objc public internal(set) var variationIdentifier: String?
    @objc public internal(set) var experimentId: String?
    internal var paywall: ApphudPaywall?

    // MARK: - Private
    internal var id: String?
    internal var itemId: String?
    internal var properties: [String: ApphudAnyCodable]?

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

    internal func jsonProperties(langCode: String = Locale.current.apphudLanguageCode(), fallback: Bool = true) -> [String: any Sendable]? {

        var innerProps: ApphudAnyCodable?
        if let props = properties {
            if props[langCode] != nil {
                innerProps = props[langCode]
            } else if fallback {
                innerProps = props.keys.first.flatMap { props[$0] }
            }
        }

        if let innerProps = innerProps?.value as? [String: ApphudAnyCodable] {
            let jsonProps = innerProps.mapValues { $0.toJSONValue() }
            return jsonProps
        } else {
            return nil
        }
    }

    internal func hasMacros() -> Bool {
        guard let jsonPros = self.jsonProperties() else {return false}

        for value in jsonPros.values {
            if let value = value as? String {
                if value.contains("{") {
                    return true
                }
            }
        }

        return false
    }
}
