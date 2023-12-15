//
//  ApphudPlacement.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 27.11.2023.
//

import Foundation

/**
 An enumeration for commonly used placement identifiers in Apphud. Ensure that the identifiers used here match those in the Apphud Product Hub -> Placements section. This enum facilitates the retrieval of specific placement configurations in your code.
 ```swift
 let placement = await Apphud.placement(ApphudPlacementID.onboarding.rawValue)
 ```
 */
public enum ApphudPlacementID: String {
    case main
    case home
    case onboarding
    case settings
    case content
    case toolbar
    case banner
}

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
    public var paywall: ApphudPaywall? { paywalls.first }

    /**
     A/B experiment name if it's paywall, if any.
     */
    public var experimentName: String? { paywall?.experimentName }

    /** For Internal Use
     */
    internal var paywalls: [ApphudPaywall]
    internal var id: String
}
