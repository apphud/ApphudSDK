//
//  ApphudPurchase.swift
//  apphud
//
//  Created by Renat on 23.02.2020.
//  Copyright © 2020 softeam. All rights reserved.
//

import Foundation

public class ApphudNonRenewingPurchase : NSObject {
    
    /**
     Product identifier of this subscription
     */
    @objc public let productId : String
    
    /**
     Date when user bought regular in-app purchase.
     */
    @objc public let purchasedAt : Date
    
    /**
     Canceled date of in-app purchase, i.e. refund date. Nil if in-app purchase is not refunded.
     */
    @objc public let canceledAt : Date?
    
    // MARK:- Private methods
    
    /// Subscription private initializer
    init?(dictionary : [String : Any]) {
        guard dictionary["kind"] as? String == "nonrenewable" else {return nil}
        canceledAt = ApphudSubscription.dateFrom(dictionary["cancelled_at"])
        productId = dictionary["product_id"] as? String ?? ""
        purchasedAt = ApphudSubscription.dateFrom(dictionary["started_at"]) ?? Date()
    }

    /**
     Returns `true` if purchase is not refunded.
     */
    @objc public func isActive() -> Bool {
        return canceledAt == nil
    }
}
