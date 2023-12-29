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
    }

    internal func setAFData(_ newValue: [AnyHashable: Any]?) {
        submittedAFData = newValue
    }

    internal func setAdjustData(_ newValue: [AnyHashable: Any]?) {
        submittedAdjustData = newValue
    }

    internal var submittedAFData: [AnyHashable: Any]? {
        get {
            let cache = apphudDataFromCache(key: submittedAFDataKey, cacheTimeout: 86_400*7)
            if let data = cache.objectsData, !cache.expired,
                let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [AnyHashable: Any] {
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

    internal var submittedAdjustData: [AnyHashable: Any]? {
        get {
            let cache = apphudDataFromCache(key: submittedAdjustDataKey, cacheTimeout: 86_400*7)
            if let data = cache.objectsData, !cache.expired,
                let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [AnyHashable: Any] {
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
}
