//
//  ApphudEnums.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 28.09.2023.
//

import Foundation

/**
 Public Callback object provide -> [String: Bool]
 */
public typealias ApphudEligibilityCallback = (([String: Bool]) -> Void)

/**
 Public Callback object provide -> Bool
 */
public typealias ApphudBoolCallback = ((Bool) -> Void)

/// List of available attribution providers
/// has to make Int in order to support Objective-C
@objc public enum ApphudAttributionProvider: Int {
    case appsFlyer
    case adjust

    @available(*, unavailable, message: "Apple Search Ads attribution via iAd framework is no longer supported by Apple. Just remove this code and use appleAdsAttribution provider via AdServices framework. For more information visit: https://docs.apphud.com/docs/apple-search-ads")
    case appleSearchAds

    case appleAdsAttribution // For iOS 14.3+ devices only, Apple Search Ads attribution via AdServices.framework
    case firebase
    case facebook

    /**
    Pass custom attribution data to Apphud. Contact your support manager for details.
     */
    case custom

    /**
     case branch
     Branch integration doesn't require any additional code from Apphud SDK
     More details: https://docs.apphud.com/docs/branch
     */

    func toString() -> String {
        switch self {
        case .appsFlyer:
            return "AppsFlyer"
        case .adjust:
            return "Adjust"
        case .facebook:
            return "Facebook"
        case .appleAdsAttribution:
            return "Apple Ads Attribution"
        case .firebase:
            return "Firebase"
        case .custom:
            return "Custom"
        default:
            return "Unavailable"
        }
    }
}

internal enum ApphudIAPCodingKeys: String, CodingKey {
    case id, expiresAt, productId, cancelledAt, startedAt, inRetryBilling, autorenewEnabled, introductoryActivated, environment, local, groupId, status, kind
}

internal enum ApphudIAPKind: String {
    case autorenewable
    case nonrenewable
}

internal enum ApphudEnvironment: String {
    case sandbox
    case production
}
