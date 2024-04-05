//
//  Router.swift
//  sampleapp
//
//  Created by Apphud on 13.02.2024.
//  Copyright © 2024 Apphud. All rights reserved.
//

import UIKit

class Router: NSObject {
    
    static let shared = Router()
    
    func showTabbar() {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let paywallViewController = storyBoard.instantiateViewController(withIdentifier: "TabBarController") as! TabBarController
        topController?.present(paywallViewController, animated: true)
    }
    
    func showOnboardingPaywall() {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Paywalls", bundle: nil)
        let paywallViewController = storyBoard.instantiateViewController(withIdentifier: "OnboardingPaywallViewController") as! OnboardingPaywallViewController
        topController?.present(paywallViewController, animated: true)
    }
    
    func showInAppPaywall(completion: @escaping ((Bool) -> Void)) {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Paywalls", bundle: nil)
        let paywallViewController = storyBoard.instantiateViewController(withIdentifier: "InAppPaywallViewController") as! InAppPaywallViewController
        paywallViewController.purchaseCallback = completion
        topController?.present(paywallViewController, animated: true)
    }
}

// MARK: - Top Controller
extension Router {
    
    var topController: UIViewController? {
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
