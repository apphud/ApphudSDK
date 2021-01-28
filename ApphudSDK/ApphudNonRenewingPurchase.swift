//
//  ApphudPurchase.swift
//  Apphud, Inc
//
//  Created by ren6 on 23.02.2020.
//  Copyright © 2020 Apphud Inc. All rights reserved.
//

import Foundation

public class ApphudNonRenewingPurchase: NSObject {

    /**
     Product identifier of this subscription
     */
    @objc public let productId: String

    /**
     Date when user bought regular in-app purchase.
     */
    @objc public let purchasedAt: Date

    /**
     Canceled date of in-app purchase, i.e. refund date. Nil if in-app purchase is not refunded.
     */
    @objc public let canceledAt: Date?

    // MARK: - Private methods

    /// Subscription private initializer
    init?(dictionary: [String: Any]) {
        guard dictionary["kind"] as? String == "nonrenewable" else {return nil}
        
        canceledAt =  (dictionary["cancelled_at"] as? String ?? "").apphudIsoDate
        purchasedAt = (dictionary["started_at"] as? String ?? "").apphudIsoDate ?? Date()
        productId = dictionary["product_id"] as? String ?? ""
    }

    /**
     Returns `true` if purchase is not refunded.
     */
    @objc public func isActive() -> Bool {
        return canceledAt == nil
    }
}
