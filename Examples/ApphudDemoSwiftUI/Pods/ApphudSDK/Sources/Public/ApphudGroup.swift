//
//  ApphudGroup.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 29.04.2021.
//

import Foundation

/**
 Apphud class which describes products permission groups
 */

public class ApphudGroup: NSObject, Codable {

    /**
     Name of permission group configured in Apphud Dashboard.
     */
    public var name: String

    /**
     You should not operate with products from ApphudGroup directly. Use Paywalls or Paywalls within Placements.
     @returns Products Identifiers that belong to this permission group.
     */
    public var productIds: [String] {
        products.map { $0.productId }
    }

    /**
     Returns `true` if this permission group has active subscription. Keep in mind, that this method doesn't distinguish consumable purchases from non-consumables.
     
     __If you have consumable purchases, do not use this method in current SDK version.__
     */
    @MainActor public var hasAccess: Bool {

        for subscription in ApphudInternal.shared.currentUser?.subscriptions ?? [] {
            if subscription.isActive() && subscription.groupId == id {
                return true
            }
        }
         
        let purchases = ApphudInternal.shared.currentUser?.purchases.filter { productIds.contains($0.productId) }
        if purchases?.count ?? 0 > 0 {
            return true
        }

        return false
    }

    // MARK: - Private

    internal var id: String
    internal var products: [ApphudProduct]
    private enum CodingKeys: String, CodingKey {
        case id
        case identifier
        case name
        case isDefault = "default"
        case jsonString = "json"
        case products = "bundles"
    }

    init(id: String, name: String, products: [ApphudProduct]) {
        self.id = id
        self.name = name
        self.products = products
    }

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        products = try values.decode([ApphudProduct].self, forKey: .products)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(name, forKey: .name)
        try container.encode(products, forKey: .products)
    }
}
