//
//  ApphudPaywall.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 29.04.2021.
//

import UIKit

public class ApphudPaywall: NSObject, Codable {
    
    public internal(set) var identifier: String
    public internal(set) var name: String
    public internal(set) var isDefault: Bool
    public var json: [String: Any]? {
        
        guard let string = jsonString, let data = string.data(using: .utf8) else {
            return [:]
        }
        
        do {
            let dict = try JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any]
            return dict
        } catch  {
            apphudLog("Failed to decode paywall JSON. Identifier: \(identifier), json: \(jsonString ?? "")")
        }
        
        return [:]
    }
    public internal(set) var products: [ApphudProduct]
    
    internal var id: String
    private var jsonString: String?
    
    private enum CodingKeys: String, CodingKey {
        case id
        case identifier
        case name
        case isDefault = "default"
        case jsonString = "json"
        case products = "items"
    }
    
    init(id: String, name: String, identifier: String, isDefault: Bool, jsonString: String?, products: [ApphudProduct]) {
        self.id = id
        self.name = name
        self.jsonString = jsonString
        self.identifier = identifier
        self.isDefault = isDefault
        self.products = products
    }
    
    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        id = try values.decode(String.self, forKey: .id)
        name = try values.decode(String.self, forKey: .name)
        identifier = try values.decode(String.self, forKey: .identifier)
        jsonString = try? values.decode(String.self, forKey: .jsonString)
        isDefault = try values.decode(Bool.self, forKey: .isDefault)
        products = try values.decode([ApphudProduct].self, forKey: .products)
    }
    
    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
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
