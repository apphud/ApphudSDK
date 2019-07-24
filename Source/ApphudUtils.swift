//
//  ApphudUtils.swift
//  subscriptionstest
//
//  Created by Renat on 12/07/2019.
//  Copyright © 2019 apphud. All rights reserved.
//

import Foundation

/**
 This class will contain some utils, more will be added in the future.
 */
public class ApphudUtils : NSObject {
    static let shared = ApphudUtils()
    private(set) var isLoggingEnabled = true
    /**
        Disables console logging.
 */
    @objc class func disableLogging() {
        shared.isLoggingEnabled = false
    }
}
