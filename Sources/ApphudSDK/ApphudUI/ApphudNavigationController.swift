//
//  ApphudNavigationController.swift
//  Apphud, Inc
//
//  Created by ren6 on 18.12.2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import Foundation
import StoreKit

internal class ApphudNavigationController: UINavigationController {

    private var pendingScreens = [ApphudScreenController]()

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

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
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
        return pendingScreens.first(where: {$0.screenID == screenID})
    }

    func handleDidDismiss() {
        ApphudInternal.shared.uiDelegate?.apphudDidDismissScreen?(controller: self)
        ApphudRulesManager.shared.pendingController = nil
    }
}

extension ApphudNavigationController: UIAdaptivePresentationControllerDelegate {

    func presentationControllerDidDismiss(_ presentationController: UIPresentationController) {
        handleDidDismiss()
    }

}
