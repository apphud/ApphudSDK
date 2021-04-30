//
//  ApphudProduct.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 29.04.2021.
//

import Foundation
import StoreKit

public class ApphudProduct: NSObject, Codable {
    
    public internal(set) var productId: String
    public internal(set) var store: String
    public internal(set) var name: String?
    public internal(set) var skProduct: SKProduct?
    public internal(set) var paywallId: String?
    internal var id: String?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case name
        case store
        case productId
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
