//
//  ApphudAttributionData.swift
//  ApphudSDK
//
//  Created by ren6 on 12/07/2019.
//  Copyright © 2019 apphud. All rights reserved.
//

@objc public class ApphudAttributionData: NSObject {
    @objc public var rawData: [AnyHashable: Any]
    
    @objc public var adNetwork: String?
    @objc public var mediaSource: String?
    @objc public var campaign: String?
    @objc public var adSet: String?
    @objc public var creative: String?
    @objc public var keyword: String?
    @objc public var custom1: String?
    @objc public var custom2: String?

    @objc public init(
        rawData: [AnyHashable: Any],
        adNetwork: String? = nil,
        mediaSource: String? = nil,
        campaign: String? = nil,
        adSet: String? = nil,
        creative: String? = nil,
        keyword: String? = nil,
        custom1: String? = nil,
        custom2: String? = nil
    ) {
        self.rawData = rawData
        super.init()
        
        let rawAdNetwork   = rawData["adNetwork"]   as? String
        let rawMediaSource = rawData["mediaSource"] as? String
        let rawCampaign    = rawData["campaign"]    as? String
        let rawAdSet       = rawData["adSet"]       as? String
        let rawCreative    = rawData["creative"]    as? String
        let rawKeyword     = rawData["keyword"]     as? String
        let rawCustom1     = rawData["custom1"]     as? String
        let rawCustom2     = rawData["custom2"]     as? String
        
        self.adNetwork   = adNetwork   ?? rawAdNetwork
        self.mediaSource = mediaSource ?? rawMediaSource
        self.campaign    = campaign    ?? rawCampaign
        self.adSet       = adSet       ?? rawAdSet
        self.creative    = creative    ?? rawCreative
        self.keyword     = keyword     ?? rawKeyword
        self.custom1     = custom1     ?? rawCustom1
        self.custom2     = custom2     ?? rawCustom2
    }
}
