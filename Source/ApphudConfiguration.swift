//
//  ApphudConfiguration.swift
//  apphud
//
//  Created by Renat on 02/06/2019.
//  Copyright © 2019 softeam. All rights reserved.
//

import UIKit

public class ApphudConfiguration: NSObject {
    
    /**
     Get user identifier of Apphud user. This is read only property and should be set only during initialization.
     */
    private(set) public var user_id: String = ""
    
    /**
     Amplitude user identifier. Optional. 
     */
    private(set) public var user_id_for_amplitude: String?

    /**
     Mixpanel user identifier. Optional. 
     */
    private(set) public var user_id_for_mixpanel: String?

    /**
     Flurry user identifier. Optional. 
     */
    private(set) public var user_id_for_flurry: String?
    
    /**
     Primary initializer
     */
    init(anUserID : String, anUserIDAmplitude : String? = nil, anUserIDMixpanel : String? = nil, anUserIDFlurry : String? = nil) {
        user_id = anUserID
        user_id_for_flurry = anUserIDFlurry
        user_id_for_amplitude = anUserIDAmplitude
        user_id_for_mixpanel = anUserIDMixpanel
    }
}
