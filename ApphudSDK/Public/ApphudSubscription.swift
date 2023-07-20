//
//  ApphudSubscription.swift
//  Apphud, Inc
//
//  Created by ren6 on 25/06/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
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
public enum ApphudSubscriptionStatus: String, Codable {
    case trial
    case intro
    case promo
    case regular
    case grace
    case refunded
    case expired
}

/**
 Custom Apphud class containing all information about customer subscription.
 */
public class ApphudSubscription: Codable {

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
    public var status: ApphudSubscriptionStatus

    /**
     Product identifier of this subscription
     */
    @objc public let productId: String

    /**
     Expiration date of subscription period. You shouldn't use this property to detect if subscription is active because user can change system date in iOS settings. Check isActive() method instead.
     */
    @objc public let expiresDate: Date

    /**
     Date when user has purchased the subscription.
     */
    @objc public let startedAt: Date

    /**
     Canceled date of subscription, i.e. refund date. Nil if subscription is not refunded.
     */
    @objc public let canceledAt: Date?

    /**
     Returns `true` if subscription is made in test environment, i.e. sandbox or local purchase.
     */
    @objc public let isSandbox: Bool

    /**
     Returns `true` if subscription was made using Local StoreKit Configuration File. Read more: https://docs.apphud.com/docs/testing-troubleshooting#local-storekit-testing
     */
    @objc public let isLocal: Bool

    /**
     Means that subscription has failed billing, but Apple will try to charge the user later.
     */
    @objc public let isInRetryBilling: Bool

    /**
     False value means that user has canceled the subscription from App Store settings. 
     */
    @objc public let isAutorenewEnabled: Bool

    /**
     True value means that user has already used introductory offer for this subscription (free trial, pay as you go or pay up front).
     
     __Note:__ If this value is false, this doesn't mean that user is eligible for introductory offer for this subscription (for all products within the same group). Subscription should also have expired status.
     
     __You shouldn't use this value__. Use `checkEligibilityForIntroductoryOffer(products: callback:)` method instead.
     */
    @objc public let isIntroductoryActivated: Bool

    @objc internal let id: String

    @objc internal let groupId: String

    // MARK: - Private methods

    private enum CodingKeys: String, CodingKey {
        case id, expiresAt, productId, cancelledAt, startedAt, inRetryBilling, autorenewEnabled, introductoryActivated, environment, local, groupId, status
    }


    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let expiresDateString = try values.decode(String.self, forKey: .expiresAt)
        guard let expDate = expiresDateString.apphudIsoDate else { throw ApphudError(message: "Missing Expires Date") }

        id = try values.decode(String.self, forKey: .id)
        expiresDate = expDate
        productId = try values.decode(String.self, forKey: .productId)
        canceledAt = try values.decode(String.self, forKey: .cancelledAt).apphudIsoDate
        startedAt = try values.decode(String.self, forKey: .startedAt).apphudIsoDate ?? Date()
        isInRetryBilling = try values.decode(Bool.self, forKey: .inRetryBilling)
        isAutorenewEnabled = try values.decode(Bool.self, forKey: .autorenewEnabled)
        isIntroductoryActivated = try values.decode(Bool.self, forKey: .introductoryActivated)
        isSandbox = (try values.decode(String.self, forKey: .environment)) == "sandbox"
        isLocal = try values.decode(Bool.self, forKey: .local)
        groupId = try values.decode(String.self, forKey: .groupId)
        status = try values.decode(ApphudSubscriptionStatus.self, forKey: .status)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(expiresDate.apphudIsoString, forKey: .expiresAt)
        try container.encode(productId, forKey: .productId)
        try? container.encode(canceledAt?.apphudIsoString, forKey: .cancelledAt)
        try container.encode(startedAt.apphudIsoString, forKey: .startedAt)
        try container.encode(isInRetryBilling, forKey: .inRetryBilling)
        try container.encode(isAutorenewEnabled, forKey: .autorenewEnabled)
        try container.encode(isIntroductoryActivated, forKey: .introductoryActivated)
        try container.encode(isLocal, forKey: .local)
        try container.encode(isSandbox ? "sandbox" : "production", forKey: .environment)
        try container.encode(groupId, forKey: .groupId)
        try container.encode(status.rawValue, forKey: .status)
    }


    /// Subscription private initializer
    init?(dictionary: [String: Any]) {
        guard let expDate = (dictionary["expires_at"] as? String ?? "").apphudIsoDate else {return nil}
        id = dictionary["id"] as? String ?? ""
        expiresDate = expDate
        productId = dictionary["product_id"] as? String ?? ""
        canceledAt =  (dictionary["cancelled_at"] as? String ?? "").apphudIsoDate
        startedAt = (dictionary["started_at"] as? String ?? "").apphudIsoDate ?? Date()
        isInRetryBilling = dictionary["in_retry_billing"] as? Bool ?? false
        isAutorenewEnabled = dictionary["autorenew_enabled"] as? Bool ?? false
        isIntroductoryActivated = dictionary["introductory_activated"] as? Bool ?? false
        isSandbox = (dictionary["environment"] as? String ?? "") == "sandbox"
        isLocal = dictionary["local"] as? Bool ?? false
        groupId = dictionary["group_id"] as? String ?? ""
        if let statusString = dictionary["status"] as? String {
            status = ApphudSubscriptionStatus(rawValue: statusString) ?? .expired
        } else {
            status = .expired
        }
    }
}
