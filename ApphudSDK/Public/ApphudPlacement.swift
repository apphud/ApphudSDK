//
//  ApphudPlacement.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 27.11.2023.
//

import Foundation

/**
 A placement is a specific location within a user's journey (such as onboarding, settings, etc.) where its internal paywall is intended to be displayed.
 */
public class ApphudPlacement: Codable {

    /**
     Placement identifier configured in Apphud Product Hub > Placements.
     */
    public var identifier: String

    /**
     Represents the paywall linked with this specific Placement.

     Returns `nil` if no paywalls are enabled in the placement configuration or if the user doesn't meet the audience criteria.
    */
    public var paywall: ApphudPaywall? {
        paywalls.first
    }

    /** For Internal Use
     */
    internal var paywalls: [ApphudPaywall]
    internal var id: String
}
