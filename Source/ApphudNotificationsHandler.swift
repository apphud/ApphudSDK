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
    var handledRules = [String]()
    
    @discardableResult internal func handleNotification(_ apsInfo: [AnyHashable : Any]) -> Bool{
        
        guard let rule_id = apsInfo["rule_id"] as? String else {
            return false
        }
        guard !handledRules.contains(rule_id) else {
            return true
        }
        
        apphudLog("handle APS: \(apsInfo as AnyObject)")
        
        handledRules.append(rule_id)
        ApphudInternal.shared.getRule(ruleID: rule_id) { rule in
            if rule != nil {
                ApphudInquiryController.show(rule: rule!)
            }
        }
        
        // allow handling the same push notification rule after 5 seconds. This is needed for testing rules from Apphud dashboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { 
            self.handledRules.removeAll()
        }
        
        return true    
    }
}
