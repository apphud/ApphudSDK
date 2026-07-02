//
//  ApphudNavigationController.swift
//  Apphud, Inc
//
//  Created by ren6 on 18.12.2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import Foundation
import StoreKit

#if os(iOS)
internal class ApphudNavigationController: UINavigationController {

    private var pendingScreens = [UIViewController]()

    override var supportedInterfaceOrientations: UIInterfaceOrientationMask {
        return .portrait
    }

    override var childForStatusBarStyle: UIViewController? {
        return self.visibleViewController
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        self.presentationController?.delegate = self
    }

    func pushScreenController(screenID: String, rule: ApphudRule) {

        var controller = pendingScreenController(screenID: screenID)
        if controller == nil {
            print("COULDNT FIND CONTROLLER IN CACHE \(screenID), creating a new one.")
            controller = ApphudScreenController(rule: rule, screenID: screenID) { _ in }
            controller!.loadScreenPage()
        } else if let index = pendingScreens.firstIndex(of: controller!) {
            pendingScreens.remove(at: index)
        }

        pushViewController(controller!, animated: true)
    }

    func preloadScreens(screenIDS: [String], rule: ApphudRule) {

        for screenID in screenIDS {
            let controller = ApphudScreenController(rule: rule, screenID: screenID) { _ in }
            controller.loadScreenPage()
            pendingScreens.append(controller)
        }
    }

    func pendingScreenController(screenID: String) -> ApphudScreenController? {
        let controller = pendingScreens.filter { cont in
            cont is ApphudScreenController && (cont as? ApphudScreenController)?.screenID == screenID
        }.first as? ApphudScreenController
        
        return controller
    }

    func handleDidDismiss() {
        let screenName = (self.viewControllers.first as? ApphudScreenController)?.rule.screen_name

        ApphudInternal.shared.uiDelegate?.apphudDidDismissScreen?(controller: self, screenName: screenName)
        ApphudInternal.shared.uiDelegate?.apphudDidDismissScreen?(controller: self)
        ApphudScreensManager.shared.pendingController = nil
    }
}

extension ApphudNavigationController: UIAdaptivePresentationControllerDelegate {

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        handleDidDismiss()
    }

}

#endif
