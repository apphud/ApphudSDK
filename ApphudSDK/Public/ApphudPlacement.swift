//
//  ApphudPlacement.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 27.11.2023.
//

import Foundation

public class ApphudPlacement: Codable {

    /**
     Placement identifier configured in Apphud Product Hub > Placements.
     */
    public var identifier: String

    /**
     Paywall associated with this Placement.
     */
    public var paywall: ApphudPaywall? {
        paywalls.first
    }

    /**
     Developer can create his own Placement in runtime as a fallback.
     */
    public init(identifier: String, paywall: ApphudPaywall) {
        self.identifier = identifier
        self.paywalls = [paywall]
        self.id = identifier
    }

    /** For Internal Use
     */
    internal var paywalls: [ApphudPaywall]

    /** For Internal Use
     */
    internal var id: String
}
