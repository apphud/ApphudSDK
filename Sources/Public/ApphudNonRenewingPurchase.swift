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

    required public init(from decoder: Decoder) throws {
        let values = try decoder.container(keyedBy: ApphudIAPCodingKeys.self)
        (self.productId, self.canceledAt, self.purchasedAt, self.isSandbox, self.isLocal) = try Self.decodeValues(from: values)
    }

    internal init(with values: KeyedDecodingContainer<ApphudIAPCodingKeys>) throws {
        (self.productId, self.canceledAt, self.purchasedAt, self.isSandbox, self.isLocal) = try Self.decodeValues(from: values)
    }

    private static func decodeValues(from values: KeyedDecodingContainer<ApphudIAPCodingKeys>) throws -> (String, Date?, Date, Bool, Bool) {

        let kind = try values.decode(String.self, forKey: .kind)

        guard kind == ApphudIAPKind.nonrenewable.rawValue else { throw ApphudError(message: "Not a nonrenewing purchase")}

        let productId = try values.decode(String.self, forKey: .productId)
        let canceledAt = try? values.decode(String.self, forKey: .cancelledAt).apphudIsoDate
        let purchasedAt = try values.decode(String.self, forKey: .startedAt).apphudIsoDate ?? Date()
        let isSandbox = (try values.decode(String.self, forKey: .environment)) == ApphudEnvironment.sandbox.rawValue
        let isLocal = try values.decode(Bool.self, forKey: .local)

        return (productId, canceledAt, purchasedAt, isSandbox, isLocal)
    }

    public func encode(to encoder: Encoder) throws {
        var container = encoder.container(keyedBy: ApphudIAPCodingKeys.self)
        try container.encode(productId, forKey: .productId)
        try? container.encode(canceledAt?.apphudIsoString, forKey: .cancelledAt)
        try container.encode(purchasedAt.apphudIsoString, forKey: .startedAt)
        try container.encode(isSandbox ? ApphudEnvironment.sandbox.rawValue : ApphudEnvironment.production.rawValue, forKey: .environment)
        try container.encode(isLocal, forKey: .local)
        try container.encode(ApphudIAPKind.nonrenewable.rawValue, forKey: .kind)
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
