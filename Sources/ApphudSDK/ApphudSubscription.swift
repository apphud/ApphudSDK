//
//  ApphudSubscription.swift
// Apphud
//
//  Created by ren6 on 25/06/2019.
//  Copyright © 2019 Softeam Inc. All rights reserved.
//

import Foundation

/**
 Status of the subscription. It can only be in one state at any moment.
 
 Possible values:
 * `trial`: Free trial period.
 * `intro`: One of introductory offers: "Pay as you go" or "Pay up front".
 * `promo`: Custom promotional offer.
 * `regular`: Regular paid subscription.
 * `grace`: Custom grace period. Configurable in web.
 * `refunded`: Subscription was refunded by Apple Care. Developer should treat this subscription as never purchased.
 * `expired`: Subscription has expired because has been canceled manually by user or had unresolved billing issues.
 */
@objc public enum ApphudSubscriptionStatus : Int {
    case trial
    case intro
    case promo
    case regular
    case grace
    case refunded
    case expired 
}

/*
 To be visible in Objective-C this has to be an NSObject inherited class
 */
public class ApphudSubscription : NSObject{
    
    /**
     Use this function to detect whether to give or not premium content to the user.
     
     - Returns: If value is `true` then user should have access to premium content.
     */
    @objc public func isActive() -> Bool {
        switch status {
        case .trial, .intro, .promo, .regular, .grace:
            return true
        default:
            return false
        }
    }
    
    /**
     The state of the subscription
     */
    @objc public var status : ApphudSubscriptionStatus
    
    /**
     Product identifier of this subscription
     */
    @objc public let productId : String
    
    /**
     Expiration date of subscription period. You shouldn't use this property to detect if subscription is active because user can change system date in iOS settings. Check isActive() method instead.
     */
    @objc public let expiresDate : Date
    
    /**
     Date when user has purchased the subscription.
     */
    @objc let startedAt : Date?
    
    /**
     Canceled date of subscription, i.e. refund date. Nil if subscription is not refunded.
     */
    @objc public let canceledAt : Date?
    
    /**
     Means that subscription has failed billing, but Apple will try to charge the user later.
     */
    @objc public let isInRetryBilling : Bool
    
    /**
     False value means that user has canceled the subscription from App Store settings. 
     */
    @objc public let isAutorenewEnabled : Bool
    
    /**
     True value means that user has already used introductory offer for this subscription (free trial, pay as you go or pay up front).
     
     __Note:__ If this value is false, this doesn't mean that user is eligible for introductory offer for this subscription (for all products within the same group). Subscription should also have expired status.
     
     __You shouldn't use this value__. Use `checkEligibilityForIntroductoryOffer(products: callback:)` method instead.
     */
    @objc public let isIntroductoryActivated : Bool
    
    @objc internal let id : String
    
    // MARK:- Private methods
    
    /// Subscription private initializer
    init?(dictionary : [String : Any]) {
        guard let expDate = ApphudSubscription.dateFrom(dictionary["expires_at"]) else {return nil}
        id = dictionary["id"] as? String ?? ""
        expiresDate = expDate
        productId = dictionary["product_id"] as? String ?? ""  
        canceledAt = ApphudSubscription.dateFrom(dictionary["cancelled_at"])
        startedAt = ApphudSubscription.dateFrom(dictionary["started_at"])
        isInRetryBilling = dictionary["in_retry_billing"] as? Bool ?? false
        isAutorenewEnabled = dictionary["autorenew_enabled"] as? Bool ?? false
        isIntroductoryActivated = dictionary["introductory_activated"] as? Bool ?? false
        if let statusString = dictionary["status"] as? String {
            status = ApphudSubscription.statusFrom(string: statusString)
        } else {
            status = .expired
        }
    }
    
    /// have to write this code because obj-c doesn't support enum to be string
    private static func statusFrom(string : String) -> ApphudSubscriptionStatus {
        switch string {
        case "trial":
            return .trial
        case "intro":
            return .intro
        case "promo":
            return .promo
        case "regular":
            return .regular
        case "grace":
            return .grace
        case "refunded":
            return .refunded
        case "expired":
            return .expired
        default:
            return .expired
        }
    }
    
    /// Helper method to parse date string into Date object
    private static func dateFrom(_ object : Any?) -> Date? {
        guard let date_string = object as? String else { return nil }
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFractionalSeconds, .withInternetDateTime, .withColonSeparatorInTimeZone, .withColonSeparatorInTime]
        let date = formatter.date(from: date_string)
        return date
    }
}

extension ApphudSubscriptionStatus {
    /**
     This function can only be used in Swift
     */
    func toString() -> String {
        
        switch self {
        case .trial:
            return "trial"
        case .intro:
            return "intro"
        case .promo:
            return "promo"
        case .grace:
            return "grace"
        case .regular:
            return "regular"
        case .refunded:
            return "refunded"
        case .expired:
            return "expired"
        default:
            return ""
        }
    }
}
