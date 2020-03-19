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
        
    private var apsInfo : [AnyHashable : Any]?
    
    @discardableResult internal func handleNotification(_ apsInfo: [AnyHashable : Any]) -> Bool{
        
        guard let rule_id = apsInfo["rule_id"] as? String else {
            return false
        }
                
        guard !handledRules.contains(rule_id) else {
            return true
        }
        
        self.apsInfo = apsInfo
        self.handledRules.append(rule_id)
        
        if UIApplication.shared.applicationState == .active {
            self.handlePendingAPSInfo()
        } else {
            // do nothing, because ApphudInternal will call once app is active
            apphudLog("Got APS info, but app is not yet active, waiting for app to be active, then will handle push notification.", forceDisplay: true)
        }
        
        return true    
    }

    @objc internal func handlePendingAPSInfo(){
        
        guard let rule_id = apsInfo?["rule_id"] as? String else {
            return
        }
        
        apphudLog("handle push notification: \(apsInfo as AnyObject)")
        
        ApphudInternal.shared.trackEvent(params: ["rule_id" : rule_id, "name" : "$push_opened"]) {}
        
        if apsInfo?["screen_id"] != nil {
            handleRule(ruleID: rule_id, data: apsInfo as? [String : Any])            
        }
        
        self.apsInfo = nil
        // allow handling the same push notification rule after 5 seconds. This is needed for testing rules from Apphud dashboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) { 
            self.handledRules.removeAll()
        }
    }
    
    internal func handleRule(ruleID: String, data: [String : Any]?){
        let dict = ["id" : ruleID].merging(data ?? [:], uniquingKeysWith: {old, new in new})
        let rule = ApphudRule(dictionary: dict)
        self.handleRule(rule: rule)
    }
    
    internal func handleRule(rule: ApphudRule) {
        
        guard self.pendingController == nil else { return }
        guard rule.screen_id.count > 0 else { return }
        guard ApphudInternal.shared.uiDelegate?.apphudShouldPerformRule?(rule: rule) ?? true else { 
            apphudLog("apphudShouldPerformRule returned false for rule \(rule.rule_name), exiting", forceDisplay: true)
            return 
        }
        
        let controller = ApphudScreenController(rule: rule, screenID: rule.screen_id) {_ in}
        controller.loadScreenPage()
        
        let nc = ApphudNavigationController(rootViewController: controller)
        nc.setNavigationBarHidden(true, animated: false)
        self.pendingController = nc
        
        if ApphudInternal.shared.uiDelegate?.apphudShouldShowScreen?(screenName: rule.screen_name) ?? true {
             showPendingScreen()
        } else {
            apphudLog("apphudShouldShowScreen returned false for screen \(rule.screen_name), exiting", forceDisplay: true)
        }
    }
    
    internal func showPendingScreen(){
        
        guard self.pendingController != nil else { return }
        
        if let style = ApphudInternal.shared.uiDelegate?.apphudScreenPresentationStyle?(controller: pendingController!){
            pendingController!.modalPresentationStyle = style
            if style == .fullScreen || style == .overFullScreen {
                pendingController!.modalPresentationCapturesStatusBarAppearance = true
            }
        }
        let parent = ApphudInternal.shared.uiDelegate?.apphudParentViewController?(controller: pendingController!) ?? apphudVisibleViewController()
        parent?.present(pendingController!, animated: true, completion: nil)
    }
    
    internal func pendingRule() -> ApphudRule? {
        if let nc = self.pendingController as? ApphudNavigationController, let screenController = nc.viewControllers.first as? ApphudScreenController {
            return screenController.rule
        } else {
            return nil
        }
    }
}
