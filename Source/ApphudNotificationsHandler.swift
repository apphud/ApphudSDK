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
        
        let action = apsInfo["action"] as? String
        let rule_id = apsInfo["rule_id"] as? String
        let screen_id = apsInfo["screen_id"] as? String
        
        if rule_id == nil {
            return false
        }
        
        if action == "present_purchase_screen" && screen_id != nil{
            trackPushOpened(ruleID: rule_id!){
                self.presentPurchaseScreen(rule_id!, screen_id!)
            }
            return true
        } else if action == "manual" {
            trackPushOpened(ruleID: rule_id!) { 
                self.notifyDelegate(ruleId: rule_id!, customData: apsInfo["custom_data"] as? [String : Any])
            }
            return true
        } else if action == "open_url" {
            trackPushOpened(ruleID: rule_id!) { 
                ApphudInternal.shared.trackMobileEvent(name: "url_opened", ruleID: rule_id!, callback: { 
                    self.handleURL(apsInfo["url"] as? String)
                })
            }
            return true
        } else if action == "appstore_settings" {
            trackPushOpened(ruleID: rule_id!) { 
                ApphudInternal.shared.trackMobileEvent(name: "payments_settings_opened", ruleID: rule_id!, callback: { 
                    self.handleOpenBilling()
                })
            }
            return true
        }
        return false
    }
    
    private func handleURL(_ urlString: String?){
        ApphudInternal.shared.performWhenUserRegistered {
            if urlString != nil, let url = URL(string: urlString!), UIApplication.shared.canOpenURL(url){
                UIApplication.shared.open(url)
            }            
        }
    }
    
    private func notifyDelegate(ruleId: String, customData: [String : Any]?){
        ApphudInternal.shared.delegate?.apphudDidReceiveNotification?(ruleID: ruleId, customData: customData)
    }
    
    private func presentPurchaseScreen(_ ruleId: String, _ screenID: String){                       
        if #available(iOS 12.2, *) {
            presentingScreenController = ApphudScreenController()
            (presentingScreenController as? ApphudScreenController)?.show(ruleID: ruleId, screenID: screenID, completionBlock: { result in
                self.presentingScreenController = nil
            })
        }        
    }
    
    private func handleOpenBilling(){
        if let url = URL(string: "itms-apps://apps.apple.com/account/subscriptions"), UIApplication.shared.canOpenURL(url){
            UIApplication.shared.open(url)
        }
    }

    private func trackPushOpened(ruleID: String, completion: @escaping () -> Void){
        ApphudInternal.shared.trackMobileEvent(name: "push_opened", ruleID: ruleID, callback: completion)
    }
}
