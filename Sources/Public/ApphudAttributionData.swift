//
//  ApphudAttributionData.swift
//  ApphudSDK
//
//  Created by ren6 on 12/07/2019.
//  Copyright © 2019 apphud. All rights reserved.
//

import Foundation

public struct ApphudAttributionData {
    
    /// Raw attribution data received from MMPs, such as AppsFlyer or Branch.
    /// Pass only `rawData` if no custom override logic is needed.
    public let rawData: [AnyHashable: Any]

    /// Overridden ad network responsible for user acquisition (e.g., "Meta Ads", "Google Ads").
    /// Leave `nil` if no custom override logic is needed.
    public let adNetwork: String?

    /// Overridden channel that drove the user acquisition (e.g., "Instagram Feed", "Google UAC").
    /// Leave `nil` if no custom override logic is needed.
    public let channel: String?

    /// Overridden campaign name associated with the attribution data.
    /// Leave `nil` if no custom override logic is needed.
    public let campaign: String?

    /// Overridden ad set name within the campaign.
    /// Leave `nil` if no custom override logic is needed.
    public let adSet: String?

    /// Overridden specific ad creative used in the campaign.
    /// Leave `nil` if no custom override logic is needed.
    public let creative: String?

    /// Overridden keyword associated with the ad campaign (if applicable).
    /// Leave `nil` if no custom override logic is needed.
    public let keyword: String?

    /// Custom attribution parameter for additional tracking or mapping.
    /// Use this to store extra attribution data if needed.
    public let custom1: String?

    /// Another custom attribution parameter for extended tracking or mapping.
    /// Use this to store extra attribution data if needed.
    public let custom2: String?

    public init(
        rawData: [AnyHashable: Any],
        adNetwork: String? = nil,
        channel: String? = nil,
        campaign: String? = nil,
        adSet: String? = nil,
        creative: String? = nil,
        keyword: String? = nil,
        custom1: String? = nil,
        custom2: String? = nil
    ) {
        self.rawData = rawData
        self.adNetwork = adNetwork
        self.channel = channel
        self.campaign = campaign
        self.adSet = adSet
        self.creative = creative
        self.keyword = keyword
        self.custom1 = custom1
        self.custom2 = custom2
    }
}
