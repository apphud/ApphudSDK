//
//  ApphudNotificationsHandler.swift
//  apphudTestApp
//
//  Created by Renat on 22/08/2019.
//  Copyright © 2019 softeam. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications

internal class ApphudNotificationsHandler {
    
    static let shared = ApphudNotificationsHandler()
        
    var presentingScreenController : Any?
    
    @discardableResult internal func handleNotification(_ apsInfo: [AnyHashable : Any]) -> Bool{
        
        apphudLog("handle APS: \(apsInfo as AnyObject)")
        
        if let rule_id = apsInfo["rule_id"] as? String {
            
            ApphudInternal.shared.getRule(ruleID: rule_id) { rule in
                if rule != nil {
                    ApphudInquiryController.show(rule: rule!)
                }
            }
            
            return true
        }
        
        return false
    }
}
