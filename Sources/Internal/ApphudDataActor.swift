//
//  ApphudDataActor.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 30.11.2023.
//

import Foundation

@globalActor actor ApphudDataActor {
    static let shared = ApphudDataActor()

    internal func clear() {
        submittedAFData = nil
        submittedAdjustData = nil
        userPropertiesCache = nil
    }

    internal func setAFData(_ newValue: [String: any Sendable]?) {
        submittedAFData = newValue
    }

    internal func setAdjustData(_ newValue: [String: any Sendable]?) {
        submittedAdjustData = newValue
    }

    internal func setUserPropertiesCache(_ newValue: [[String: Any?]]?) {
        userPropertiesCache = newValue
    }
    
    private(set) var pendingUserProps = [ApphudUserProperty]()
    
    internal func addPendingUserProperty(_ newValue: ApphudUserProperty) {
        self.pendingUserProps.removeAll { prop -> Bool in newValue.key == prop.key }
        self.pendingUserProps.append(newValue)
    }
    
    internal func setPendingUserProperties(_ newValue: [ApphudUserProperty]) {
        self.pendingUserProps = newValue
    }

    internal var submittedAFData: [String: any Sendable]? {
        get {
            let cache = apphudDataFromCache(key: submittedAFDataKey, cacheTimeout: 86_400*7)
            if let data = cache.objectsData, !cache.expired,
               let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: any Sendable] {
                return object
            } else {
                return nil
            }
        }
        set {
            if newValue != nil, let data = try? JSONSerialization.data(withJSONObject: newValue!, options: .prettyPrinted) {
                apphudDataToCache(data: data, key: submittedAFDataKey)
            }
        }
    }

    internal var submittedAdjustData: [String: any Sendable]? {
        get {
            let cache = apphudDataFromCache(key: submittedAdjustDataKey, cacheTimeout: 86_400*7)
            if let data = cache.objectsData, !cache.expired,
               let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: any Sendable] {
                return object
            } else {
                return nil
            }
        }
        set {
            if newValue != nil, let data = try? JSONSerialization.data(withJSONObject: newValue!, options: .prettyPrinted) {
                apphudDataToCache(data: data, key: submittedAdjustDataKey)
            }
        }
    }

    internal var userPropertiesCache: [[String: Any?]]? {
        get {
            let cache = apphudDataFromCache(key: ApphudUserPropertiesCacheKey, cacheTimeout: 86_400*7)
            if let data = cache.objectsData, !cache.expired,
                let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any?]] {
                return object
            } else {
                return nil
            }
        }
        set {
            if newValue != nil, let data = try? JSONSerialization.data(withJSONObject: newValue!, options: .prettyPrinted) {
                apphudDataToCache(data: data, key: ApphudUserPropertiesCacheKey)
            } else if newValue == nil {
                apphudDataClearCache(key: ApphudUserPropertiesCacheKey)
            }
        }
    }

    internal func apphudDataClearCache(key: String) {
        if var url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            url.appendPathComponent(key)
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
        }
    }

    internal func apphudDataToCache(data: Data, key: String) {
        if var url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            url.appendPathComponent(key)
            if FileManager.default.fileExists(atPath: url.path) {
                try? FileManager.default.removeItem(at: url)
            }
            try? data.write(to: url)
        }
    }

    internal func apphudDataFromCache(key: String, cacheTimeout: TimeInterval) -> (objectsData: Data?, expired: Bool) {
        if var url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
            url.appendPathComponent(key)

            if FileManager.default.fileExists(atPath: url.path),
               let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
               let creationDate = attrs[.creationDate] as? Date,
               let data = try? Data(contentsOf: url) {
                return (data, (Date().timeIntervalSince(creationDate) > cacheTimeout))
            }
        }
        return (nil, true)
    }
}
