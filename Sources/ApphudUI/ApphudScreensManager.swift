//
//  ApphudScreensManager.swift
//  apphudTestApp
//
//  Created by ren6 on 22/08/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import Foundation
import UserNotifications
#if canImport(UIKit)
import UIKit
#endif

#if os(iOS)
@MainActor
internal class ApphudScreensManager {
    static let shared = ApphudScreensManager()
    var pendingController: UIViewController?

    var pendingPaywallControllers: [String: UIViewController] = [:]

    private var handledRules = [String]()

    private var apsInfo: [AnyHashable: Any]?

    internal func preloadPlacements(identifiers: [String]) {
        ApphudInternal.shared.fetchOfferingsFull(maxAttempts: APPHUD_DEFAULT_RETRIES) { _ in
            for placement in ApphudInternal.shared.placements {
                if identifiers.contains(placement.identifier), let p = placement.paywall {
                    self.preloadPaywall(p)
                }
            }
        }
    }

    @MainActor
    internal func preloadPaywall(_ paywall: ApphudPaywall) {
        _ = try? requestPaywallController(paywall: paywall)
    }

    internal func unloadPaywalls(_ identifier: String? = nil) {
        if let identifier {
            pendingPaywallControllers.removeValue(forKey: identifier)
        } else {
            pendingPaywallControllers.removeAll()
        }
    }

    internal func requestPaywallcontroller(_ paywall: ApphudPaywall, maxTimeout: TimeInterval = APPHUD_PAYWALL_SCREEN_LOAD_TIMEOUT, completion: @escaping (ApphudPaywallScreenFetchResult) -> Void) {
        do {
            let controller = try requestPaywallController(paywall: paywall)
            switch controller.state {
            case .error(let error):
                completion(.error(error: error))
            case .loading:
                controller.onLoad(maxTimeout: maxTimeout) { error in
                    completion(error != nil ? .error(error: error!) : .success(controller: controller))
                }
            case .ready:
                completion(.success(controller: controller))
            }
        } catch {
            completion(.error(error: error as? ApphudError ?? ApphudError(error: error)))
        }
    }

    @MainActor
    internal func requestPaywallController(paywall: ApphudPaywall) throws -> ApphudPaywallScreenController {

        if let vc = ApphudScreensManager.shared.pendingPaywallControllers[paywall.identifier] as? ApphudPaywallScreenController {

            switch vc.state {
            case .error(let e):
                unloadPaywalls(paywall.identifier)
                throw e
            case .loading, .ready:
                apphudLog("Using preloaded paywall \(paywall.identifier)")
                return vc
            }
        }

        guard paywall.hasVisualPaywall() else {
            let e = ApphudError(message: "Paywall \(paywall.identifier) has no visual URL", code: APPHUD_PAYWALL_SCREEN_NOT_FOUND)
            apphudLog(e.localizedDescription, forceDisplay: true)
            throw e
        }

        let vc = ApphudPaywallScreenController(paywall: paywall)
        ApphudScreensManager.shared.pendingPaywallControllers[paywall.identifier] = vc
        vc.load()

        return vc
    }

    @discardableResult internal func handleNotification(_ apsInfo: [AnyHashable: Any]) -> Bool {

        guard let rule_id = apsInfo["rule_id"] as? String else {
            return false
        }

        guard !handledRules.contains(rule_id) else {
            return true
        }

        self.apsInfo = apsInfo
        self.handledRules.append(rule_id)

        self.handlePendingAPSInfo()

        return true
    }

    @objc internal func handlePendingAPSInfo() {

        guard UIApplication.shared.applicationState == .active else {
            apphudLog("Got APS info, but app is not yet active, waiting for app to be active, then will handle push notification.", forceDisplay: true)
            return
        }

        guard let rule_id = apsInfo?["rule_id"] as? String else {
            return
        }

        apphudLog("handle push notification: \(apsInfo as AnyObject)")

        ApphudInternal.shared.trackEvent(params: ["rule_id": rule_id, "name": "$push_opened"]) {}

        if apsInfo?["screen_id"] != nil {
            handleRule(ruleID: rule_id, data: apsInfo as? [String: Any])
        }

        self.apsInfo = nil
        // allow handling the same push notification rule after 5 seconds. This is needed for testing rules from Apphud dashboard
        DispatchQueue.main.asyncAfter(deadline: .now() + 5) {
            self.handledRules.removeAll()
        }
    }

    internal func handleRule(ruleID: String, data: [String: Any]?) {
        let dict = ["id": ruleID].merging(data ?? [:], uniquingKeysWith: {_, new in new})
        let rule = ApphudRule(dictionary: dict)
        self.handleRule(rule: rule)
    }

    internal func handleRule(rule: ApphudRule) {

        guard self.pendingController == nil else { return }
        guard rule.screen_id.count > 0 || rule.paywallIdentifier != nil else { return }
        guard ApphudInternal.shared.uiDelegate?.apphudShouldPerformRule?(rule: rule) ?? true else {
            ApphudInternal.shared.readAllNotifications(for: rule.id)
            apphudLog("apphudShouldPerformRule returned false for rule \(rule.rule_name), exiting", forceDisplay: true)
            return
        }

        if let pId = rule.paywallIdentifier {
            presentRulePaywall(rule: rule, id: pId)
        } else {
            presentRuleScreen(rule: rule)
        }
    }
    
    internal func presentRulePaywall(rule: ApphudRule, id: String) {
        ApphudInternal.shared.fetchPaywall(identifier: id) { paywall in
            if let paywall {
                self.requestPaywallcontroller(paywall) { result in
                    switch result {
                        case .error(let error):
                            // Might be a timeout issue, invalid or missing paywall URL, or another error
                            // Show your default paywall
                            apphudLog("error during paywall fetch: \(error)")
                        case .success(let controller):
                            let parent = ApphudInternal.shared.uiDelegate?.apphudParentViewController?(controller: controller) ?? apphudVisibleViewController()
                            parent?.present(controller, animated: true)
                            controller.rule = rule
                            controller.onFinished = { result in
                                switch result {
                                case .success(let purchase):
                                    // User made a purchase or restored, allow to dismiss
                                    return .allow
                                case .failure(let error):
                                    // User canceled a payment or an error occurred. do not dismiss
                                    return .cancel
                                case .userClosed:
                                    // User closed a paywall, allow to dismiss
                                    return .allow
                                }
                            }
                        }
                }
            }
        }
    }
    
    internal func presentRuleScreen(rule: ApphudRule) {
        let controller = ApphudScreenController(rule: rule, screenID: rule.screen_id) {_ in}
        controller.loadScreenPage()

        let nc = ApphudNavigationController(rootViewController: controller)
        nc.setNavigationBarHidden(true, animated: false)
        self.pendingController = nc

        if ApphudInternal.shared.uiDelegate?.apphudShouldShowScreen?(screenName: rule.screen_name) ?? true {
             showPendingScreen()
        } else {
            ApphudInternal.shared.readAllNotifications(for: rule.id)
            apphudLog("apphudShouldShowScreen returned false for screen \(rule.screen_name), exiting", forceDisplay: true)
        }
    }

    internal func showPendingScreen() {

        guard self.pendingController != nil else { return }

        if let style = ApphudInternal.shared.uiDelegate?.apphudScreenPresentationStyle?(controller: pendingController!) {
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

    internal func cacheActiveScreens() {
        ApphudInternal.shared.getActiveRuleScreens { ids in
            ids.forEach { id in
                ApphudHttpClient.shared.loadScreenHtmlData(screenID: id) { _, _ in }
            }
        }
    }
}
#endif
