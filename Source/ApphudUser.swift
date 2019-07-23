//
//  ApphudUser.swift
//  subscriptionstest
//
//  Created by Renat on 25/06/2019.
//  Copyright © 2019 apphud. All rights reserved.
//

import Foundation

fileprivate let ApphudUserCacheKey = "ApphudUserCacheKey"

public struct ApphudUser {
    let user_id : String
    let subscriptions : [ApphudSubscription]?
    
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
        self.subscriptions = subs
    }
    
    static func toCache(_ dictionary : [String : Any]) {
        do {
            let data = try NSKeyedArchiver.archivedData(withRootObject: dictionary, requiringSecureCoding: false)
            let documentsURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
            let fileURL = documentsURL.appendingPathComponent("ApphudUser.data")            
            try data.write(to: fileURL)
        } catch {
            print("error: \(error.localizedDescription)")
        }
    }
    
    static func fromCache() -> ApphudUser?{
        do {
            if let documentsURL = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
                let fileURL = documentsURL.appendingPathComponent("ApphudUser.data")
                let data = try Data(contentsOf: fileURL)
                
                if let dictionary = try NSKeyedUnarchiver.unarchiveTopLevelObjectWithData(data) as? [String : Any] {
                    return ApphudUser(dictionary: dictionary)
                }
            }
        } catch {
            print("error: \(error.localizedDescription)")
        }
        return nil
    }
}
