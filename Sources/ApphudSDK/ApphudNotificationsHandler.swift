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

@available(iOS 11.2, *)
internal class ApphudNotificationsHandler {
    
    static let shared = ApphudNotificationsHandler()        
    var handledRules = [String]()
    
    var pendingController : ApphudScreenController?
    
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
        
        pendingController = ApphudScreenController(rule: rule, screenID: rule.screen_id) { result in
            if result {
//                self.displayPendingController()
            } else {
                self.pendingController = nil
            }
        }
        pendingController?.loadScreenPage()
        self.displayPendingController()
    }
    
    internal func displayPendingController(){
        
        guard pendingController != nil else {return}
        guard !alreadyDisplayed() else { return }
        
        let nc = ApphudNavigationController(rootViewController: pendingController!)
        
        if let style = ApphudInternal.shared.delegate?.apphudScreenPresentationStyle?(){
             nc.modalPresentationStyle = style
        }
        
        nc.setNavigationBarHidden(true, animated: false)
        
        apphudVisibleViewController()?.present(nc, animated: true, completion: nil) 
        self.pendingController = nil
    }
}

class ApphudNavigationController: UINavigationController {
    
    private var pendingScreens = [ApphudScreenController]()
    
    override var supportedInterfaceOrientations: UIInterfaceOrientationMask{
        get {
            return .portrait
        }
    }
    
    func pushScreenController(screenID: String, rule: ApphudRule){
        
        var controller = pendingScreenController(screenID: screenID)
        if controller == nil {
            print("COULDNT FIND CONTROLLER IN CACHE \(screenID), creating a new one.")
            controller = ApphudScreenController(rule: rule, screenID: screenID) { ready in }
            controller!.loadScreenPage()
        }
        pushViewController(controller!, animated: true)
    }
    
    func preloadScreens(screenIDS: [String], rule: ApphudRule){
        
        for screenID in screenIDS {
            let controller = ApphudScreenController(rule: rule, screenID: screenID) { ready in }
            controller.loadScreenPage()
            pendingScreens.append(controller)
        }
    }
    
    func pendingScreenController(screenID: String) -> ApphudScreenController? {
        return pendingScreens.first(where: {$0.screenID == screenID})
    }
}
