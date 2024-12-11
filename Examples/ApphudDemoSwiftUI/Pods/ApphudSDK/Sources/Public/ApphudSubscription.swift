//
//  ApphudSubscription.swift
//  Apphud, Inc
//
//  Created by ren6 on 25/06/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import Foundation
import StoreKit

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
        if groupId == stub_key {
            return expiresDate > Date()
        }

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
    public let status: ApphudSubscriptionStatus

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

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: ApphudIAPCodingKeys.self)
        (self.id, self.expiresDate, self.productId, self.canceledAt, self.startedAt, self.isInRetryBilling, self.isAutorenewEnabled, self.isIntroductoryActivated, self.isSandbox, self.isLocal, self.groupId, self.status) = try Self.decodeValues(from: values)
    }

    internal init(with values: KeyedDecodingContainer<ApphudIAPCodingKeys>) throws {
        (self.id, self.expiresDate, self.productId, self.canceledAt, self.startedAt, self.isInRetryBilling, self.isAutorenewEnabled, self.isIntroductoryActivated, self.isSandbox, self.isLocal, self.groupId, self.status) = try Self.decodeValues(from: values)
    }

    private static func decodeValues(from values: KeyedDecodingContainer<ApphudIAPCodingKeys>) throws -> (String, Date, String, Date?, Date, Bool, Bool, Bool, Bool, Bool, String, ApphudSubscriptionStatus) {

        let expiresDateString = try values.decode(String.self, forKey: .expiresAt)
        guard let expDate = expiresDateString.apphudIsoDate else { throw ApphudError(message: "Missing Expires Date") }

        let id = try values.decode(String.self, forKey: .id)
        let expiresDate = expDate
        let productId = try values.decode(String.self, forKey: .productId)
        let canceledAt = try? values.decode(String.self, forKey: .cancelledAt).apphudIsoDate
        let startedAt = try values.decode(String.self, forKey: .startedAt).apphudIsoDate ?? Date()
        let isInRetryBilling = try values.decode(Bool.self, forKey: .inRetryBilling)
        let isAutorenewEnabled = try values.decode(Bool.self, forKey: .autorenewEnabled)
        let isIntroductoryActivated = try values.decode(Bool.self, forKey: .introductoryActivated)
        let isSandbox = (try values.decode(String.self, forKey: .environment)) == ApphudEnvironment.sandbox.rawValue
        let isLocal = try values.decode(Bool.self, forKey: .local)
        let groupId = try values.decode(String.self, forKey: .groupId)
        let status = try values.decode(ApphudSubscriptionStatus.self, forKey: .status)

        return (id, expiresDate, productId, canceledAt, startedAt, isInRetryBilling, isAutorenewEnabled, isIntroductoryActivated, isSandbox, isLocal, groupId, status)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ApphudIAPCodingKeys.self)
        try container.encode(id, forKey: .id)
        try container.encode(expiresDate.apphudIsoString, forKey: .expiresAt)
        try container.encode(productId, forKey: .productId)
        try? container.encode(canceledAt?.apphudIsoString, forKey: .cancelledAt)
        try container.encode(startedAt.apphudIsoString, forKey: .startedAt)
        try container.encode(isInRetryBilling, forKey: .inRetryBilling)
        try container.encode(isAutorenewEnabled, forKey: .autorenewEnabled)
        try container.encode(isIntroductoryActivated, forKey: .introductoryActivated)
        try container.encode(isLocal, forKey: .local)
        try container.encode(isSandbox ? ApphudEnvironment.sandbox.rawValue : ApphudEnvironment.production.rawValue, forKey: .environment)
        try container.encode(groupId, forKey: .groupId)
        try container.encode(status.rawValue, forKey: .status)
        try container.encode(ApphudIAPKind.autorenewable.rawValue, forKey: .kind)
    }

    internal init(product: SKProduct) {
        id = product.productIdentifier
        expiresDate = Date().addingTimeInterval(3600)
        productId = product.productIdentifier
        canceledAt = nil
        startedAt = Date()
        isInRetryBilling = false
        isAutorenewEnabled = true
        isSandbox = apphudIsSandbox()
        isLocal = false
        groupId = stub_key
        status = product.apphudIsTrial ? .trial : product.apphudIsPaidIntro ? .intro : .regular
        isIntroductoryActivated = status == .trial || status == .intro
    }

    internal var stateDescription: String {
        [String(expiresDate.timeIntervalSince1970), productId, status.rawValue, String(isAutorenewEnabled)].joined(separator: "|")
    }

    internal let stub_key = "apphud_stub"
}
