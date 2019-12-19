//
//  ApphudRulesManager.swift
//  apphudTestApp
//
//  Created by Renat on 22/08/2019.
//  Copyright © 2019 softeam. All rights reserved.
//

import Foundation
import UIKit
import UserNotifications

@available(iOS 11.2, *)
internal class ApphudRulesManager {
    
    static let shared = ApphudRulesManager()        
    var pendingController : UIViewController?
    
    private var handledRules = [String]()
        
    @discardableResult internal func handleNotification(_ apsInfo: [AnyHashable : Any]) -> Bool{
        
        guard let rule_id = apsInfo["rule_id"] as? String else {
            return false
        }
        guard !handledRules.contains(rule_id) else {
            return true
        }
        
        apphudLog("handle APS: \(apsInfo as AnyObject)")
        
        handledRules.append(rule_id)
        handleRule(ruleID: rule_id)
        
        // allow handling the same push notification rule after 5 seconds. This is needed for testing rules from Apphud dashboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { 
            self.handledRules.removeAll()
        }
        
        return true    
    }
    
    internal func handleRule(ruleID: String){
        ApphudInternal.shared.getRule(ruleID: ruleID) { rule in
            if rule != nil {
                self.handleRule(rule: rule!)
            }
        }
    }
    
    internal func alreadyDisplayed() -> Bool {
        return apphudVisibleViewController() is ApphudNavigationController
    }
    
    internal func handleRule(rule: ApphudRule) {
        
        guard !alreadyDisplayed() else { return }
        
        let controller = ApphudScreenController(rule: rule, screenID: rule.screen_id) {_ in}
        controller.loadScreenPage()
        
        let nc = ApphudNavigationController(rootViewController: controller)
        nc.setNavigationBarHidden(true, animated: false)
        
        if ApphudInternal.shared.uiDelegate?.apphudShouldShowScreen?(controller: nc) ?? true {
            self.pendingController = nil
            if let style = ApphudInternal.shared.uiDelegate?.apphudScreenPresentationStyle?(controller: nc){
                 nc.modalPresentationStyle = style
            }
            apphudVisibleViewController()?.present(nc, animated: true, completion: nil) 
        } else {
            self.pendingController = nc
        }
    }
}
