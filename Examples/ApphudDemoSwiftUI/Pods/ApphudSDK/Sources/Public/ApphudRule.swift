//
//  ApphudRule.swift
//  Apphud, Inc
//
//  Created by ren6 on 30/08/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//
import Foundation
/**
 An object containing all incoming Rule information.
*/

public class ApphudRule: NSObject {

    /**
     Rule name that is visible in Apphud Rules Dashboard
     */
    @objc public let rule_name: String

    /**
     Screen name that is visible in Apphud Screens Dashboard
     */
    @objc public let screen_name: String

    // Private
    internal let id: String
    internal let screen_id: String

    // MARK: - Private methods

    /// Subscription private initializer
    init(dictionary: [String: Any]) {
        id = dictionary["id"] as? String ?? ""
        screen_id = dictionary["screen_id"] as? String ?? ""
        rule_name = dictionary["rule_name"] as? String ?? ""
        screen_name = dictionary["screen_name"] as? String ?? ""
    }
}
