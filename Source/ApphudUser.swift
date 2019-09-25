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
    
    // MARK:- Private methods
    
    init?(dictionary : [String : Any]) {
        guard let userID = dictionary["user_id"] as? String else { return nil }
        self.user_id = userID
        
        var subs = [ApphudSubscription]()
        if let subscriptionsDictsArray = dictionary["subscriptions"] as? [[String : Any]]{
            for subdict in subscriptionsDictsArray {
                if let subscription = ApphudSubscription(dictionary: subdict) {
                    subs.append(subscription)
                }
            }
        }
        if subs.count > 0 {
            self.subscriptions = subs.sorted{ return $0.expiresDate > $1.expiresDate }
        } else {
            self.subscriptions = []
        }
    }
    
    func subscriptionsStates() -> [String : String] {
        var dict = [String : String]()
        for subscription in self.subscriptions {
            dict[subscription.productId] = subscription.status.toString()
        }
        return dict
    }
    
    static func toCache(_ dictionary : [String : Any]) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: dictionary, requiringSecureCoding: false)
            let documentsURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let fileURL = documentsURL.appendingPathComponent("ApphudUser.data")            
            try data.write(to: fileURL)
        } catch {
            apphudLog("failed to write to cache apphud user json, error: \(error.localizedDescription)")
        }
    }
    
    static func fromCache() -> ApphudUser?{
        do {
            if let documentsURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
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
            apphudLog("failed to read from cache apphud user json, error: \(error.localizedDescription)")
        }
        return nil
    }
}
