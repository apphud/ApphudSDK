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
        
        self.adNetwork   = adNetwork
        self.mediaSource = mediaSource
        self.campaign    = campaign
        self.adSet       = adSet
        self.creative    = creative
        self.keyword     = keyword
        self.custom1     = custom1
        self.custom2     = custom2
    }
}
