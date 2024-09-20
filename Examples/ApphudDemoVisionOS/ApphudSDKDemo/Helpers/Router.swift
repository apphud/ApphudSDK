//
//  Router.swift
//  ApphudSDKDemo
//
//  Created by Valery on 15.06.2021.
//  Copyright © 2021 Apphud. All rights reserved.
//

import UIKit

@MainActor
class Router: NSObject {

    static let shared = Router()

    func showRepeatPaywall(_ id: PaywallID, purchaseCallback: @escaping (Bool) -> Void, completion: @escaping () -> Void) {
        let storyBoard: UIStoryboard = UIStoryboard(name: "Main", bundle: nil)
        let paywallRepeatController = storyBoard.instantiateViewController(withIdentifier: "PaywallViewController") as! PaywallViewController
        paywallRepeatController.purchaseCallback = purchaseCallback
        paywallRepeatController.dismissCompletion = completion
        let nc = UINavigationController(rootViewController: paywallRepeatController)
        topController.present(nc, animated: true)
    }
}

// MARK: - Top Controller
extension Router {

    var topController: UIViewController! {
        return topController()
    }

    func topController(controller: UIViewController? = UIApplication.shared.windows.filter { $0.isKeyWindow }.first?.rootViewController) -> UIViewController? {
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
