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

    // MARK: - Private methods

    enum CodingKeys: CodingKey {
        case userId
        case subscriptions
        case purchases
        case paywalls
        case currency
        case autorenewables
        case nonrenewables
    }

    init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.paywalls = try? values.decode([ApphudPaywall].self, forKey: .paywalls)
        self.userId = try values.decode(String.self, forKey: .userId)

        self.currency = try? values.decode(ApphudCurrency.self, forKey: .currency)

        var subs = try? values.decodeIfPresent([ApphudSubscription].self, forKey: .autorenewables)
        var purchs = try? values.decodeIfPresent([ApphudNonRenewingPurchase].self, forKey: .nonrenewables)

        var inAppPurchases = try values.decode([ApphudInAppPurchase].self, forKey: .subscriptions)

        self.subscriptions = []
        self.purchases = []
        inAppPurchases.forEach { iap in
            switch iap {
            case .subscription(let sub):
                subscriptions.append(sub)
            case .purchase(let purch):
                purchases.append(purch)
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

    init?(userID: String, subscriptions: [ApphudSubscription] = [], purchases: [ApphudNonRenewingPurchase] = []) {
        self.userId = userID
        self.subscriptions = subscriptions
        self.purchases = purchases
    }

    /*
    init?(dictionary: [String: Any]) {
        guard let userID = dictionary["user_id"] as? String else { return nil }
        self.userId = userID

        if let currencyDict = dictionary["currency"] as? [String: Any], let currencyCode = currencyDict["code"] as? String, let countryCode = currencyDict["country_code"] as? String {
            self.currency = ApphudCurrency(countryCode: countryCode, code: currencyCode)
        }

        var subs = [ApphudSubscription]()
        var inapps = [ApphudNonRenewingPurchase]()

        if let iapDict = dictionary["subscriptions"] as? [[String: Any]],
           let data = try? JSONSerialization.data(withJSONObject: iapDict, options: []) {

            do {
                let decoder = JSONDecoder()
                decoder.keyDecodingStrategy = .convertFromSnakeCase

//                     NEED ANOTHER WAY, MAYBE CONVERT EACH DICT TO DATA ?

                subs = try decoder.decode([ApphudSubscription].self, from: data)
                inapps = try decoder.decode([ApphudNonRenewingPurchase].self, from: data)
            } catch {
                apphudLog("User subs parse error:\(error)")
            }
        }

        self.subscriptions = subs.sorted {
            if ($0.isActive() && $1.isActive()) || (!$0.isActive() && !$1.isActive()) {
                return $0.expiresDate > $1.expiresDate
            } else {
                return $0.isActive()
            }
        }

        self.purchases = inapps.sorted {
            if ($0.isActive() && $1.isActive()) || (!$0.isActive() && !$1.isActive()) {
                return $0.purchasedAt > $1.purchasedAt
            } else {
                return $0.isActive()
            }
        }
    }
     */

    func subscriptionsStates() -> Set<String> {
        let states = subscriptions.map { $0.stateDescription }
        return Set(states)
    }

    func purchasesStates() -> Set<String> {
        let states = purchases.map { $0.stateDescription }
        return Set(states)
    }

    static let userDataFileName = "ApphudUser.data"
    static let ApphudUserKey = "ApphudUser"
    static let ApphudMigrateCachesKey = "ApphudMigrateCachesKey"

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
            UserDefaults.standard.setValue(true, forKey: Self.ApphudMigrateCachesKey)

            let user = fromCache()
            let encoder = JSONEncoder()
            do {
                let data = try encoder.encode(user)
                apphudDataToCache(data: data, key: Self.ApphudUserKey)
            } catch {
                apphudLog("Failed to save user to cache: \(error)")
            }
            return user
        }

        do {
            if let data = apphudDataFromCache(key: Self.ApphudUserKey, cacheTimeout: 86_400*90).objectsData {
                let user = try JSONDecoder().decode(ApphudUser.self, from: data)
                return user
            }
        } catch {
            apphudLog("Failed to decode user from cache: \(error)")
        }

        return nil
    }

    private static func fromCache(directory: FileManager.SearchPathDirectory) -> ApphudUser? {
        do {
            if let documentsURL = FileManager.default.urls(for: directory, in: .userDomainMask).first {
                let fileURL = documentsURL.appendingPathComponent(userDataFileName)

                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    return nil
                }

                let data = try Data(contentsOf: fileURL)

                if let dictionary = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String: Any] {
                    let decoder = JSONDecoder()
                    decoder.keyDecodingStrategy = .convertFromSnakeCase

                    return try decoder.decode(ApphudUser.self, from: data)
                }
            }
        } catch {
            apphudLog("failed to read from cache apphud user json, error: \(error)", forceDisplay: true)
        }
        return nil
    }

    private static func fromCache() -> ApphudUser? {
        if let user = fromCache(directory: .applicationSupportDirectory) {
            return user
        } else {
            return fromCache(directory: .cachesDirectory)
        }
    }

    static func clearCache() {

        apphudDataClearCache(key: ApphudUserKey)

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
}
