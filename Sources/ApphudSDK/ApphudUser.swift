//
//  ApphudUser.swift
// Apphud
//
//  Created by ren6 on 25/06/2019.
//  Copyright © 2019 Softeam Inc. All rights reserved.
//

import Foundation

fileprivate let ApphudUserCacheKey = "ApphudUserCacheKey"

internal struct ApphudUser {
    /**
     Unique user identifier. This can be updated later.
     */
    var user_id : String
    /**
     An array of subscriptions that user has ever purchased.
     */
    var subscriptions : [ApphudSubscription]
    var purchases : [ApphudNonRenewingPurchase]
    
    var currencyCode: String?
    var countryCode: String?
    
    // MARK:- Private methods
    
    init?(dictionary : [String : Any]) {
        guard let userID = dictionary["user_id"] as? String else { return nil }
        self.user_id = userID
        
        if let currencyDict = dictionary["currency"] as? [String : Any] {
            self.currencyCode = currencyDict["code"] as? String
            self.countryCode = currencyDict["country_code"] as? String
        }
        
        var subs = [ApphudSubscription]()
        var inapps = [ApphudNonRenewingPurchase]()
        
        if let subscriptionsDictsArray = dictionary["subscriptions"] as? [[String : Any]]{
            for subdict in subscriptionsDictsArray {
                if let subscription = ApphudSubscription(dictionary: subdict) {
                    subs.append(subscription)
                } else if let purchase = ApphudNonRenewingPurchase(dictionary: subdict) {
                    inapps.append(purchase)
                }
            }
        }
        self.subscriptions = subs.sorted{ return $0.expiresDate > $1.expiresDate }
        self.purchases = inapps.sorted{ return $0.purchasedAt > $1.purchasedAt }
    }
    
    func subscriptionsStates() -> [[String : AnyHashable]] {
        var array = [[String : AnyHashable]]()
        for subscription in self.subscriptions {
            var dict = [String : AnyHashable]()
            dict["status"] = subscription.status.toString()
            dict["expires_date"] = subscription.expiresDate
            dict["product_id"] = subscription.productId
            dict["autorenew"] = subscription.isAutorenewEnabled
            array.append(dict)
        }
        return array
    }
    
    func purchasesStates() -> [[String : AnyHashable]] {
        var array = [[String : AnyHashable]]()
        for purchase in self.purchases {
            var dict = [String : AnyHashable]()
            dict["cancelled_at"] = purchase.canceledAt
            dict["started_at"] = purchase.purchasedAt
            dict["product_id"] = purchase.productId
            array.append(dict)
        }
        return array
    }
    
    static func toCache(_ dictionary : [String : Any]) {
        
        let data = try? NSKeyedArchiver.archivedData(withRootObject: dictionary, requiringSecureCoding: false)
        let folderURL = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        let fileURL = folderURL.appendingPathComponent("ApphudUser.data")            
        do {
            try FileManager.default.createDirectory(at: folderURL, withIntermediateDirectories: true, attributes: nil)
            try data?.write(to: fileURL)
        } catch {
            apphudLog("failed to write to cache apphud user json, error: \(error.localizedDescription)", forceDisplay: true)
        }
    }
    
    static func fromCache(directory: FileManager.SearchPathDirectory) -> ApphudUser? {
        do {
            if let documentsURL = FileManager.default.urls(for: directory, in: .userDomainMask).first {
                let fileURL = documentsURL.appendingPathComponent("ApphudUser.data")
                
                if !FileManager.default.fileExists(atPath: fileURL.path) {
                    return nil
                }
                
                let data = try Data(contentsOf: fileURL)
                
                if let dictionary = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String : Any] {
                    return ApphudUser(dictionary: dictionary)
                }
            }
        } catch {
            apphudLog("failed to read from cache apphud user json, error: \(error.localizedDescription)", forceDisplay: true)
        }
        return nil
    }
    
    static func fromCache() -> ApphudUser?{
        if let user = fromCache(directory: .applicationSupportDirectory) {
            return user
        } else {
            return fromCache(directory: .cachesDirectory)
        }
    }
}
