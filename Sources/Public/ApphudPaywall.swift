//
//  ApphudPaywall.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 29.04.2021.
//
import Foundation

/**
 An enumeration for commonly used paywall identifiers in Apphud. Ensure that the identifiers used here match those in the Apphud Product Hub -> Paywalls section. This enum facilitates the retrieval of specific paywall configurations in your code.
 ```swift
 let paywall = await Apphud.paywall(ApphudPaywallID.onboarding.rawValue)
 ```
 */
public enum ApphudPaywallID: String {
    case main
    case home
    case onboarding
    case settings
    case content
    case toolbar
    case banner
}

/**
 An object associated with purchases container (Paywall).
 
 Paywalls configured in Apphud Dashboard > Product Hub > Paywalls. Each paywall contains an array of `ApphudProduct` objects that you use for purchase. A paywall is a product array with custom JSON. The array is ordered and may be used to display products on your in-app purchase screen.
 
 #### Related Articles:
 To get paywall by identifier :
  ```swift
 let paywall = await Apphud.paywall(ApphudPaywallID.onboarding.rawValue)
  ```
 
 - Note: An alternative way of getting ``Apphud/paywalls()``

 - Important: For more information  - [Paywalls Documentation](https://docs.apphud.com/docs/paywalls)
 */

public class ApphudPaywall: NSObject, Codable, ObservableObject {

    /**
     Array of products
     */
    @Published @objc public internal(set) var products: [ApphudProduct]
    
    /**
     Your custom paywall identifier from Apphud Dashboard
     */
    @objc public internal(set) var identifier: String
    
    /**
     It's possible to make a paywall default – it's a special alias name, that can be assigned to only ONE paywall at a time. There can be no default paywalls at all. It's up to you whether you want to have them or not.
     */
    @objc public internal(set) var isDefault: Bool
    
    /**
     A/B test experiment name
     */
    @objc public var experimentName: String?
    
    /**
     A/B Experiment Variation Name
     */
    @objc public var variationName: String?
    
    /**
     Represents the identifier of a parent paywall from which an experiment variation was derived in A/B Experiments. This property is populated only if the 'Use existing paywall' option was selected during the setup of the experiment variation.
    */
    @objc public var parentPaywallIdentifier: String?

    /**
     Current paywall's placement identifier, if available.
     */
    @objc public internal(set) var placementIdentifier: String?
    
    /**
     Insert any parameters you need into custom JSON. It could be titles, descriptions, localisations, font, background and color parameters, URLs to media content, etc. Parameters count are not limited.
     */
    @objc public var json: [String: Any]? {

        guard let string = jsonString, let data = string.data(using: .utf8) else {
            return [:]
        }

        do {
            let dict = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
            return dict
        } catch {
            apphudLog("Failed to decode paywall JSON. Identifier: \(identifier), json: \(jsonString ?? "")")
        }

        return [:]
    }

    internal var id: String
    private var jsonString: String?
    internal var name: String
    internal var placementId: String?
    internal var variationIdentifier: String?
    internal var experimentId: String?

    @MainActor
    internal func update(placementId: String?, placementIdentifier: String?) {
        objectWillChange.send()
        self.placementId = placementId
        self.placementIdentifier = placementIdentifier
        products.forEach({ product in
            product.paywallId = id
            product.paywallIdentifier = identifier
            product.placementId = placementId
            product.placementIdentifier = placementIdentifier
            product.experimentId = experimentId
            product.variationIdentifier = variationIdentifier
            product.skProduct = ApphudStoreKitWrapper.shared.products.first(where: { $0.productIdentifier == product.productId })
        })
    }

    private enum CodingKeys: String, CodingKey {
        case id
        case identifier
        case name
        case experimentName
        case experimentId
        case variationIdentifier
        case variationName
        case isDefault = "default"
        case jsonString = "json"
        case products = "items"
        case parentPaywallIdentifier = "fromPaywall"
    }

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        experimentName = try? values.decode(String.self, forKey: .experimentName)
        variationName = try? values.decode(String.self, forKey: .variationName)
        variationIdentifier = try? values.decode(String.self, forKey: .variationIdentifier)
        experimentId = try? values.decode(String.self, forKey: .experimentId)
        parentPaywallIdentifier = try? values.decode(String.self, forKey: .parentPaywallIdentifier)
        identifier = try values.decode(String.self, forKey: .identifier)
        jsonString = try? values.decode(String.self, forKey: .jsonString)
        isDefault = try values.decode(Bool.self, forKey: .isDefault)
        products = try values.decode([ApphudProduct].self, forKey: .products)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try? container.encode(experimentName, forKey: .experimentName)
        try? container.encode(variationName, forKey: .variationName)
        try? container.encode(variationIdentifier, forKey: .variationIdentifier)
        try? container.encode(experimentId, forKey: .experimentId)
        try? container.encode(parentPaywallIdentifier, forKey: .parentPaywallIdentifier)
        try container.encode(name, forKey: .name)
        try container.encode(identifier, forKey: .identifier)
        try? container.encode(jsonString, forKey: .jsonString)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(products, forKey: .products)
    }
}
