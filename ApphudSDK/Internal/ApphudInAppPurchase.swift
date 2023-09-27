//
//  ApphudInAppPurchase.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 27.09.2023.
//

import Foundation

enum ApphudInAppPurchase: Codable {

    case subscription(ApphudSubscription)
    case purchase(ApphudNonRenewingPurchase)

    enum CodingKeys: CodingKey, CaseIterable {
        case subscription
        case purchase
    }

    init(from decoder: Decoder) throws {
        var container = try decoder.unkeyedContainer()

        if let sub = try container.decodeIfPresent(ApphudSubscription.self) {
            self = ApphudInAppPurchase.subscription(sub)
            return
        }

        if let purch = try container.decodeIfPresent(ApphudNonRenewingPurchase.self) {
            self = ApphudInAppPurchase.purchase(purch)
            return
        }

        throw DecodingError.valueNotFound(Self.self, DecodingError.Context(codingPath: CodingKeys.allCases, debugDescription: "subscription or purchase not found"))
    }
}
