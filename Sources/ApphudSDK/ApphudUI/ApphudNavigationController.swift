//
//  ApphudNavigationController.swift
//  apphud
//
//  Created by Renat on 18.12.2019.
//  Copyright © 2019 softeam. All rights reserved.
//

import Foundation
import StoreKit

internal class ApphudNavigationController: UINavigationController {
    
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
