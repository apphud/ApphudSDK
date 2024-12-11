//
//  ApphudUser.swift
//  Apphud, Inc
//
//  Created by ren6 on 25/06/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import Foundation

internal struct ApphudCurrency: Codable {
    let countryCode: String
    let code: String?
    let storeId: String?
    let countryCodeAlpha3: String?
}

public struct ApphudUser: Codable {

    /**
     Unique user identifier. This can be updated later.
     */
    public let userId: String

    /**
     An array of subscriptions of any statuses that user has ever purchased.
     */
    public let subscriptions: [ApphudSubscription]

    /**
     An array of non-renewing purchases of any statuses that user has ever purchased.
     */
    public let purchases: [ApphudNonRenewingPurchase]

    /**
    A list of paywall placements, potentially altered based on the user's involvement in A/B testing, if any. A placement is a specific location within a user's journey (such as onboarding, settings, etc.) where its internal paywall is intended to be displayed.

     - Important: This function doesn't await until inner `SKProduct`s are loaded from the App Store. That means placements may or may not have inner StoreKit products at the time you call this function.

    To get placements with awaiting for StoreKit products, use await Apphud.placements() or
     Apphud.placementsDidLoadCallback(...) functions.

    - Returns: An array of `ApphudPlacement` objects, representing the configured placements.
    */
    @MainActor public func rawPlacements() -> [ApphudPlacement] {
        ApphudInternal.shared.placements
    }

    /**
    A list of paywalls, potentially altered based on the user's involvement in A/B testing, if any.

    - Important: This function doesn't await until inner `SKProduct`s are loaded from the App Store. That means paywalls may or may not have inner StoreKit products at the time you call this function.

    To get paywalls with awaiting for StoreKit products, use await Apphud.paywalls() or
     Apphud.paywallsDidLoadCallback(...) functions.

    - Returns: An array of `ApphudPaywall` objects, representing the configured paywalls.
    */
    @MainActor public func rawPaywalls() -> [ApphudPaywall] {
        ApphudInternal.shared.paywalls
    }

    internal let paywalls: [ApphudPaywall]?
    internal let placements: [ApphudPlacement]?
    internal let currency: ApphudCurrency?

    // MARK: - Initializer Methods

    enum CodingKeys: CodingKey {
        case userId
        case subscriptions
        case purchases
        case paywalls
        case placements
        case currency
        case autorenewables
        case nonrenewables
        case swizzleDisabled
    }

    public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        self.paywalls = try? values.decode([ApphudPaywall].self, forKey: .paywalls)
        self.placements = try? values.decode([ApphudPlacement].self, forKey: .placements)
        self.userId = try values.decode(String.self, forKey: .userId)

        self.currency = try? values.decode(ApphudCurrency.self, forKey: .currency)

        let parsedSubs = try? values.decodeIfPresent([ApphudSubscription].self, forKey: .autorenewables)
        let parsedPurchs = try? values.decodeIfPresent([ApphudNonRenewingPurchase].self, forKey: .nonrenewables)

        var subs = parsedSubs ?? []
        var purchs = parsedPurchs ?? []

        if parsedSubs == nil || parsedPurchs == nil {

            let swizzleDisabled = (try? values.decodeIfPresent(Bool.self, forKey: .swizzleDisabled)) ?? false
            UserDefaults.standard.set(swizzleDisabled, forKey: ApphudInternal.shared.swizzlePaymentDisabledKey)

            var IAPContainer = try values.nestedUnkeyedContainer(forKey: .subscriptions)
            while !IAPContainer.isAtEnd {
                do {
                    let item = try IAPContainer.nestedContainer(keyedBy: ApphudIAPCodingKeys.self)

                    let kind = try item.decode(String.self, forKey: .kind)
                    if kind == ApphudIAPKind.autorenewable.rawValue {
                        let s = try ApphudSubscription(with: item)
                        subs.append(s)
                    } else {
                        let p = try ApphudNonRenewingPurchase(with: item)
                        purchs.append(p)
                    }
                } catch {
                    apphudLog("IAPContainer Error: \(error)")
                }
            }
        }

        subs.sort {
            if ($0.isActive() && $1.isActive()) || (!$0.isActive() && !$1.isActive()) {
                return $0.expiresDate > $1.expiresDate
            } else {
                return $0.isActive()
            }
        }

        purchs.sort {
            if ($0.isActive() && $1.isActive()) || (!$0.isActive() && !$1.isActive()) {
                return $0.purchasedAt > $1.purchasedAt
            } else {
                return $0.isActive()
            }
        }

        self.subscriptions = subs
        self.purchases = purchs
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(userId, forKey: .userId)
        try? container.encode(paywalls, forKey: .paywalls)
        try? container.encode(placements, forKey: .placements)

        try container.encode(subscriptions, forKey: .autorenewables)
        try container.encode(purchases, forKey: .nonrenewables)
        try? container.encode(currency, forKey: .currency)
    }

    init?(userID: String, subscriptions: [ApphudSubscription] = [], purchases: [ApphudNonRenewingPurchase] = [], paywalls: [ApphudPaywall] = [], placements: [ApphudPlacement] = []) {
        self.userId = userID
        self.subscriptions = subscriptions
        self.purchases = purchases
        self.paywalls = paywalls
        self.placements = placements
        self.currency = nil
    }

    // MARK: - INTERNAL AND LEGACY METHODS

    internal func subscriptionsStates() -> Set<String> {
        let states = subscriptions.map { $0.stateDescription }
        return Set(states)
    }

    internal func purchasesStates() -> Set<String> {
        let states = purchases.map { $0.stateDescription }
        return Set(states)
    }

    private static let ApphudMigrateCachesKey = "ApphudMigrateCachesKey"

    func toCacheV2() async {
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(self)
            await ApphudDataActor.shared.apphudDataToCache(data: data, key: ApphudUserCacheKey)
        } catch {
            apphudLog("Failed to save user to cache: \(error)")
        }
    }

    static func fromCacheV2() -> ApphudUser? {

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
            if let data = apphudDataFromCacheSync(key: ApphudUserCacheKey, cacheTimeout: 86_400*90).objectsData {
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
            Task {
                if let data = try? encoder.encode(user) {
                    await ApphudDataActor.shared.apphudDataToCache(data: data, key: ApphudUserCacheKey)
                    apphudLog("Successfully migrated user to CacheV2")
                }
            }
        }

        UserDefaults.standard.setValue(true, forKey: Self.ApphudMigrateCachesKey)

        return user
    }

    static func clearCache() async {
        await ApphudDataActor.shared.apphudDataClearCache(key: ApphudUserCacheKey)
        await clearCacheLegacy()
    }

    @MainActor
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
