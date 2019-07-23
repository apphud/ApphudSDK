//
//  ApphudSubscription.swift
//  subscriptionstest
//
//  Created by Renat on 25/06/2019.
//  Copyright © 2019 apphud. All rights reserved.
//

import Foundation
import SwiftDate

enum ApphudSubscriptionStatus : String {
    case active
    case trial
    case expired 
}

public struct ApphudSubscription {
    
    /**
     Returns the state of subscription. "Active" state means that user should have access to premium content for this subscription
     */
    let status : ApphudSubscriptionStatus
    
    /**
     Product identifier of this subscription
     */
    let productId : String
    /**
     Canceled date of subscription, i.e. refund date.
     */
    let canceledAt : Date?
    
    /**
     Expiration date of subscription period. You shouldn't use this property to detect if subscription is active because user can change system date in iOS settings. Check status property instead.
     */
    let expiresDate : Date
    
    /**
     Date when subscription was purchased.
     */
    let startedAt : Date?
    
    /**
     Grace period means subscription has failed billing, but Apple will try to charge the user later. Even if subscription is expired, it's status will remain active until billing issue is resolved (or not).
     */
    let isGracePeriod : Bool
    
    init?(dictionary : [String : Any]) {
        guard let expDate = ApphudSubscription.dateFrom(dictionary["expires_at"]) else {return nil}
        expiresDate = expDate
        #warning("product ID")
        productId = "" 
        canceledAt = ApphudSubscription.dateFrom(dictionary["cancelled_at"])
        startedAt = ApphudSubscription.dateFrom(dictionary["started_at"])
        isGracePeriod = dictionary["in_retry_billing"] as? Bool ?? false
        if let statusString = dictionary["status"] as? String {
            status = ApphudSubscriptionStatus(rawValue: statusString) ?? ApphudSubscriptionStatus.expired
        } else {
            status = .expired
        }
    }
    
    private static func dateFrom(_ object : Any?) -> Date? {
        guard let date_string = object as? String else { return nil }
        
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFractionalSeconds, .withInternetDateTime, .withColonSeparatorInTimeZone, .withColonSeparatorInTime]
        let date = formatter.date(from: date_string)
        return date
    }
}
