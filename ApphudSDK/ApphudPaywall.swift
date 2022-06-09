//
//  ApphudPaywall.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 29.04.2021.
//
import Foundation

/**
 An object associated with purchases container (Paywall).
 
 Paywalls configured in Apphud Dashboard > Product Hub > Paywalls. Each paywall contains an array of `ApphudProduct` objects that you use for purchase. A paywall is a product array with custom JSON. The array is ordered and may be used to display products on your in-app purchase screen.
 
 #### Related Articles:
 To get paywall by identifier :
  ```swift
 Apphud.paywallsDidLoadCallback { paywalls in
     let paywall = paywalls.first(where: {$0.identifier == "custom_paywall_identifier"})
 }
  ```
 
 - Note: An alternative way of getting ``Apphud/paywalls``
 
 - Important: For more information  - [Paywalls Documentation](https://docs.apphud.com/getting-started/product-hub/paywalls)
 */

public class ApphudPaywall: NSObject, Codable {
    
    /**
     Array of products
     */
    @objc public internal(set) var products: [ApphudProduct]
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
     A/B test variation name
     */
    @objc public var variationName: String?
    /**
     A/B test paywall identifier
     */
    @objc public var fromPaywall: String?
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

    private enum CodingKeys: String, CodingKey {
        case id
        case identifier
        case name
        case experimentName
        case fromPaywall
        case variationName
        case isDefault = "default"
        case jsonString = "json"
        case products = "items"
    }

    init(dictionary: [String: Any]) {
        self.id = dictionary["id"] as? String ?? ""
        self.name = dictionary["name"] as? String ?? ""
        self.identifier = dictionary["identifier"] as? String ?? ""
        self.isDefault = dictionary["default"] as? Bool ?? false
        self.experimentName = dictionary["experiment_name"] as? String
        self.fromPaywall = dictionary["from_paywall"] as? String
        self.variationName = dictionary["variation_name"] as? String
        self.jsonString = dictionary["json"] as? String
        self.products = []

        if let products = dictionary["items"] as? [[String: Any]] {
            self.products = products.map { ApphudProduct(dictionary: $0) }
        }
    }

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        experimentName = try? values.decode(String.self, forKey: .experimentName)
        fromPaywall = try? values.decode(String.self, forKey: .fromPaywall)
        variationName = try? values.decode(String.self, forKey: .variationName)
        identifier = try values.decode(String.self, forKey: .identifier)
        jsonString = try? values.decode(String.self, forKey: .jsonString)
        isDefault = try values.decode(Bool.self, forKey: .isDefault)
        products = try values.decode([ApphudProduct].self, forKey: .products)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try? container.encode(experimentName, forKey: .experimentName)
        try? container.encode(fromPaywall, forKey: .fromPaywall)
        try? container.encode(variationName, forKey: .variationName)
        try container.encode(name, forKey: .name)
        try container.encode(identifier, forKey: .identifier)
        try? container.encode(jsonString, forKey: .jsonString)
        try container.encode(isDefault, forKey: .isDefault)
        try container.encode(products, forKey: .products)
    }

    static func clearCache() {
        guard let folderURLAppSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {return}
        guard let folderURLCaches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {return}
        let fileURLOne = folderURLAppSupport.appendingPathComponent("ApphudPaywalls")
        let fileURLTwo = folderURLCaches.appendingPathComponent("ApphudPaywalls")
        if FileManager.default.fileExists(atPath: fileURLOne.path) {
            do {
                try FileManager.default.removeItem(at: fileURLOne)
            } catch {
                apphudLog("failed to clear apphud cache, error: \(error.localizedDescription)", forceDisplay: true)
            }
        }
        if FileManager.default.fileExists(atPath: fileURLTwo.path) {
            do {
                try FileManager.default.removeItem(at: fileURLTwo)
            } catch {
                apphudLog("failed to clear apphud cache, error: \(error.localizedDescription)", forceDisplay: true)
            }
        }
    }
}
