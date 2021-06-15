//
//  Router.swift
//  ApphudSDKDemo
//
//  Created by Валерий Левшин on 15.06.2021.
//  Copyright © 2021 softeam. All rights reserved.
//

import UIKit

class Router: NSObject {
    
    static let shared = Router()
    
    func showRepeatPaywall(completion: @escaping ()->()) {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let paywallRepeatController = storyBoard.instantiateViewController(withIdentifier: "PaywallViewControllerid") as! PaywallViewController
        paywallRepeatController.dismissCompletion = completion
        topController.present(paywallRepeatController, animated: true)
    }
}

// MARK: - Top Controller
extension Router {
    
    var topController: UIViewController! {
        return topController()
    }
    
    func topController(controller: UIViewController? = UIApplication.shared.keyWindow?.rootViewController) -> UIViewController? {
        if let navigationController = controller as? UINavigationController {
            return topController(controller: navigationController.visibleViewController)
        }
        if let tabController = controller as? UITabBarController {
            if let selected = tabController.selectedViewController {
                return topController(controller: selected)
            }
        }
        if let presented = controller?.presentedViewController {
            return topController(controller: presented)
        }
        return controller
    }
}
