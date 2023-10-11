//
//  ApphudUser.swift
//  Apphud, Inc
//
//  Created by ren6 on 25/06/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import Foundation

private let ApphudUserCacheKey = "ApphudUserCacheKey"

internal struct ApphudCurrency: Codable {
    let countryCode: String
    let code: String
}

internal struct ApphudUser: Codable {
    /**
     Unique user identifier. This can be updated later.
     */
    var userId: String
    /**
     An array of subscriptions that user has ever purchased.
     */
    var subscriptions: [ApphudSubscription]
    var purchases: [ApphudNonRenewingPurchase]
    var paywalls: [ApphudPaywall]?

    var currency: ApphudCurrency?

    // MARK: - Initializer Methods

    enum CodingKeys: CodingKey {
        case userId
        case subscriptions
        case purchases
        case paywalls
        case currency
        case autorenewables
        case nonrenewables
        case swizzleDisabled
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.paywalls = try? values.decode([ApphudPaywall].self, forKey: .paywalls)
        self.userId = try values.decode(String.self, forKey: .userId)

        self.currency = try? values.decode(ApphudCurrency.self, forKey: .currency)

        let subs = try? values.decodeIfPresent([ApphudSubscription].self, forKey: .autorenewables)
        var purchs: [ApphudNonRenewingPurchase]?
        do {
            purchs = try values.decodeIfPresent([ApphudNonRenewingPurchase].self, forKey: .nonrenewables)
        } catch {
            apphudLog("purchases parse error: \(error)")
        }

        if subs != nil && purchs != nil {
            self.subscriptions = subs!
            self.purchases = purchs!
        } else {

            let swizzleDisabled = (try? values.decodeIfPresent(Bool.self, forKey: .swizzleDisabled)) ?? false
            UserDefaults.standard.set(swizzleDisabled, forKey: ApphudInternal.shared.swizzlePaymentDisabledKey)

            self.subscriptions = []
            self.purchases = []

            var IAPContainer = try values.nestedUnkeyedContainer(forKey: .subscriptions)
            while !IAPContainer.isAtEnd {
                do {
                    let item = try IAPContainer.nestedContainer(keyedBy: ApphudIAPCodingKeys.self)

                    let kind = try item.decode(String.self, forKey: .kind)
                    if kind == ApphudIAPKind.autorenewable.rawValue {
                        let s = try ApphudSubscription(with: item)
                        subscriptions.append(s)
                    } else {
                        let p = try ApphudNonRenewingPurchase(with: item)
                        purchases.append(p)
                    }
                } catch {
                    apphudLog("IAPContainer Error: \(error)")
                }
            }
        }

        subscriptions.sort {
            if ($0.isActive() && $1.isActive()) || (!$0.isActive() && !$1.isActive()) {
                return $0.expiresDate > $1.expiresDate
            } else {
                return $0.isActive()
            }
        }

        purchases.sort {
            if ($0.isActive() && $1.isActive()) || (!$0.isActive() && !$1.isActive()) {
                return $0.purchasedAt > $1.purchasedAt
            } else {
                return $0.isActive()
            }
        }
    }

    func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try? container.encode(paywalls, forKey: .paywalls)

        try container.encode(subscriptions, forKey: .autorenewables)
        try container.encode(purchases, forKey: .nonrenewables)
        try? container.encode(currency, forKey: .currency)
    }

    init?(userID: String, subscriptions: [ApphudSubscription] = [], purchases: [ApphudNonRenewingPurchase] = [], paywalls: [ApphudPaywall] = []) {
        self.userId = userID
        self.subscriptions = subscriptions
        self.purchases = purchases
        self.paywalls = paywalls
    }


    //MARK: - INTERNAL AND LEGACY METHODS

    internal func subscriptionsStates() -> Set<String> {
        let states = subscriptions.map { $0.stateDescription }
        return Set(states)
    }

    internal func purchasesStates() -> Set<String> {
        let states = purchases.map { $0.stateDescription }
        return Set(states)
    }

    private static let ApphudMigrateCachesKey = "ApphudMigrateCachesKey"
    private static let ApphudUserKey = "ApphudUser"

    func toCacheV2() {

        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            apphudDataToCache(data: data, key: Self.ApphudUserKey)
        } catch {
            apphudLog("Failed to save user to cache: \(error)")
        }
    }

    static func fromCacheV2(_ newInstall: Bool = false) -> ApphudUser? {

        if !UserDefaults.standard.bool(forKey: Self.ApphudMigrateCachesKey) {
            do {
                let user = try migrateUserFromCacheIfNeeded()
                return user
            } catch {
                apphudLog("Failed to migrate user error: \(error)")
            }
            return nil
        }

        do {
            if let data = apphudDataFromCache(key: Self.ApphudUserKey, cacheTimeout: 86_400*90).objectsData {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase
                let user = try decoder.decode(ApphudUser.self, from: data)
                return user
            }
        } catch {
            apphudLog("Failed to decode user from cache: \(error)")
        }

        return nil
    }

    private static let userDataFileName = "ApphudUser.data"

    private static func migrateUserFromCacheIfNeeded() throws -> ApphudUser? {
        let encoder = JSONEncoder()

        let user = try fromCacheLegacy()

        if user != nil {
            let data = try encoder.encode(user)
            apphudDataToCache(data: data, key: Self.ApphudUserKey)
            apphudLog("Successfully migrated user to CacheV2")
        }

        UserDefaults.standard.setValue(true, forKey: Self.ApphudMigrateCachesKey)

        return user
    }

    static func clearCache() {
        apphudDataClearCache(key: ApphudUserKey)
        clearCacheLegacy()
    }

    private static func clearCacheLegacy() {
        guard let folderURLAppSupport = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first else {return}
        guard let folderURLCaches = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else {return}
        let fileURLOne = folderURLAppSupport.appendingPathComponent(userDataFileName)
        let fileURLTwo = folderURLCaches.appendingPathComponent(userDataFileName)
        if FileManager.default.fileExists(atPath: fileURLOne.path) {
            do {
                try FileManager.default.removeItem(at: fileURLOne)
            } catch {
                apphudLog("failed to clear apphud cache, error: \(error)", forceDisplay: true)
            }
        }
        if FileManager.default.fileExists(atPath: fileURLTwo.path) {
            do {
                try FileManager.default.removeItem(at: fileURLTwo)
            } catch {
                apphudLog("failed to clear apphud cache, error: \(error)", forceDisplay: true)
            }
        }
    }

    private static func fromCacheLegacy(directory: FileManager.SearchPathDirectory) throws -> ApphudUser? {
        guard let documentsURL = FileManager.default.urls(for: directory, in: .userDomainMask).first else {
            return nil
        }

        let fileURL = documentsURL.appendingPathComponent(userDataFileName)

        guard FileManager.default.fileExists(atPath: fileURL.path) else {
            return nil
        }

        let data = try Data(contentsOf: fileURL)

        if let dictionary = try NSKeyedUnarchiver.unarchivedObject(ofClasses: [NSDictionary.self, NSNumber.self, NSString.self, NSDate.self, NSNull.self, NSArray.self], from: data) as? [String: Any] {

            let jsonData = try JSONSerialization.data(withJSONObject: dictionary)

            let decoder = JSONDecoder()
            decoder.keyDecodingStrategy = .convertFromSnakeCase

            return try decoder.decode(ApphudUser.self, from: jsonData)
        }

        return nil
    }

    private static func fromCacheLegacy() throws -> ApphudUser? {
        if let user = try fromCacheLegacy(directory: .applicationSupportDirectory) {
            return user
        } else {
            return try fromCacheLegacy(directory: .cachesDirectory)
        }
    }
}
