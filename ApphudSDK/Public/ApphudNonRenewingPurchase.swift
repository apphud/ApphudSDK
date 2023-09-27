//
//  ApphudPurchase.swift
//  Apphud, Inc
//
//  Created by ren6 on 23.02.2020.
//  Copyright © 2020 Apphud Inc. All rights reserved.
//

import Foundation
import StoreKit

/**
 Custom Apphud class containing all information about customer non-renewing purchase
 */

public class ApphudNonRenewingPurchase: Codable {

    /**
     Product identifier of this subscription
     */
    public let productId: String

    /**
     Date when user bought regular in-app purchase.
     */
    public let purchasedAt: Date

    /**
     Canceled date of in-app purchase, i.e. refund date. Nil if in-app purchase is not refunded.
     */
    public let canceledAt: Date?

    /**
     Returns `true` if purchase is made in test environment, i.e. sandbox or local purchase.
     */
    public let isSandbox: Bool

    /**
     Returns `true` if purchase was made using Local StoreKit Configuration File. Read more: https://docs.apphud.com/docs/testing-troubleshooting#local-storekit-testing
     */
    public let isLocal: Bool

    // MARK: - Private methods

    private enum CodingKeys: String, CodingKey {
        case id, purchasedAt, productId, cancelledAt, environment, local, kind
    }

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: CodingKeys.self)
        let kind = try values.decode(String.self, forKey: .kind)

        guard kind == "nonrenewable" else { throw ApphudError(message: "Not a nonrenewing purchase")}

        productId = try values.decode(String.self, forKey: .productId)
        canceledAt = try? values.decode(String.self, forKey: .cancelledAt).apphudIsoDate
        purchasedAt = try values.decode(String.self, forKey: .purchasedAt).apphudIsoDate ?? Date()
        isSandbox = (try values.decode(String.self, forKey: .environment)) == "sandbox"
        isLocal = try values.decode(Bool.self, forKey: .local)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: CodingKeys.self)
        try container.encode(productId, forKey: .productId)
        try? container.encode(canceledAt?.apphudIsoString, forKey: .cancelledAt)
        try container.encode(purchasedAt.apphudIsoString, forKey: .purchasedAt)
        try container.encode(isSandbox ? "sandbox" : "production", forKey: .environment)
        try container.encode(isLocal, forKey: .local)
    }

    /// Subscription private initializer
    init?(dictionary: [String: Any]) {
        guard dictionary["kind"] as? String == "nonrenewable" else {return nil}

        canceledAt =  (dictionary["cancelled_at"] as? String ?? "").apphudIsoDate
        purchasedAt = (dictionary["started_at"] as? String ?? "").apphudIsoDate ?? Date()
        productId = dictionary["product_id"] as? String ?? ""
        isSandbox = (dictionary["environment"] as? String ?? "") == "sandbox"
        isLocal = dictionary["local"] as? Bool ?? false
    }

    /**
     Returns `true` if purchase is not refunded.
     */
    @objc public func isActive() -> Bool {
        if canceledAt != nil && canceledAt!.timeIntervalSince(purchasedAt) < 3700 {
            return canceledAt! > Date()
        }
        return canceledAt == nil
    }

    internal init(product: SKProduct) {
        productId = product.productIdentifier
        purchasedAt = Date()
        canceledAt = Date().addingTimeInterval(3600)
        isSandbox = apphudIsSandbox()
        isLocal = false
    }

    internal var stateDescription: String {
        [String(canceledAt?.timeIntervalSince1970 ?? 0), productId, String(purchasedAt.timeIntervalSince1970)].joined(separator: "|")
    }
}
