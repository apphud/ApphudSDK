//
//  ApphudScreenController+Actions.swift
//  apphud
//
//  Created by Renat on 01.07.2020.
//  Copyright © 2020 softeam. All rights reserved.
//

import Foundation
import WebKit
import StoreKit
import SafariServices

@available(iOS 11.2, *)
extension ApphudScreenController: WKNavigationDelegate {

    func handleNavigationAction(navigationAction: WKNavigationAction) -> Bool {

        if webView.tag == 1, let url = navigationAction.request.url {

            let lastComponent = url.lastPathComponent

            switch lastComponent {
            case "action":
                self.handleAction(url: url)
                return false
            case "screen":
                self.handleNavigation(url: url)
                return false
            case "link":
                self.handleLink(url: url)
                return false
            case "dismiss":
                self.closeTapped()
                return false
            default:
                break
            }
        }

        return true
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView.tag == 1 {
            handleScreenDidLoad()
        }
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        if webView.tag != 1 {
            failed(error)
        }
    }

    func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        if handleNavigationAction(navigationAction: navigationAction) {
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }
}

extension ApphudScreenController {

    private func isSurveyAnswer(urlComps: URLComponents) -> Bool {
        let type = urlComps.queryItems?.first(where: { $0.name == "type" })?.value
        let question = urlComps.queryItems?.first(where: { $0.name == "question" })?.value
        let answer = urlComps.queryItems?.first(where: { $0.name == "answer" })?.value
        return question != nil && answer != nil && type != "post_feedback"
    }

    private func handleAction(url: URL) {

        guard let urlComps = URLComponents(url: url, resolvingAgainstBaseURL: true) else {return}
        guard let action = urlComps.queryItems?.first(where: { $0.name == "type" })?.value else {return}

        switch action {
        case "purchase":
            let productID = urlComps.queryItems?.first(where: { $0.name == "product_id" })?.value
            let offerID = urlComps.queryItems?.first(where: { $0.name == "offer_id" })?.value
            purchaseProduct(productID: productID, offerID: offerID)
        case "restore":
            restoreTapped()
        case "dismiss":
            if isSurveyAnswer(urlComps: urlComps) {
                handleSurveyAnswer(urlComps: urlComps, answerAndDismiss: true)
            } else {
                closeTapped()
            }
        case "post_feedback":
            handlePostFeedbackTapped(urlComps: urlComps)
        case "billing_issue":
            handleBillingIssueTapped()
        default:
            break
        }
    }

    private func handleNavigation(url: URL) {

        guard let urlComps = URLComponents(url: url, resolvingAgainstBaseURL: true) else {return}
        guard let screen_id = urlComps.queryItems?.first(where: { $0.name == "id" })?.value else {return}

        if isSurveyAnswer(urlComps: urlComps) {
            handleSurveyAnswer(urlComps: urlComps, answerAndDismiss: false)
        }

        guard let nc = navigationController as? ApphudNavigationController else {return}

        nc.pushScreenController(screenID: screen_id, rule: self.rule)
    }

    private func handleLink(url: URL) {

        let urlComps = URLComponents(url: url, resolvingAgainstBaseURL: true)

        guard let urlString = urlComps?.queryItems?.first(where: { $0.name == "url" })?.value else {
            return
        }

        guard let navigationURL = URL(string: urlString) else {
            return
        }

        if UIApplication.shared.canOpenURL(navigationURL) {
            let controller = SFSafariViewController(url: navigationURL)
            controller.modalPresentationStyle = self.navigationController?.modalPresentationStyle ?? .fullScreen
            present(controller, animated: true, completion: nil)
        }
    }

    internal func handleReadNotificationsOnce() {
        // perform only for initial screen in view controllers stack
        if self == navigationController?.viewControllers.first {
            ApphudInternal.shared.readAllNotifications(for: self.rule.id)
        }
    }

    internal func handleScreenPresented() {
        ApphudInternal.shared.trackEvent(params: ["rule_id": self.rule.id, "screen_id": self.screenID, "name": "$screen_presented"]) {}
    }

    private func handleSurveyAnswer(urlComps: URLComponents, answerAndDismiss: Bool) {

        let question = urlComps.queryItems?.first(where: { $0.name == "question" })?.value
        let answer = urlComps.queryItems?.first(where: { $0.name == "answer" })?.value

        if question != nil && answer != nil {
            ApphudInternal.shared.trackEvent(params: ["rule_id": self.rule.id, "screen_id": self.screenID, "name": "$survey_answer", "properties": ["question": question!, "answer": answer!]]) {}
        }

        if answerAndDismiss {
            thankForFeedbackAndClose(isSurvey: true)
        }
    }

    internal func handlePurchaseResult(product: SKProduct, offerID: String? = nil, result: ApphudPurchaseResult) {

        let errorCode: SKError.Code
        if let skError = result.transaction?.error as? SKError {
            errorCode = skError.code
        } else {
            errorCode = .unknown
        }

        let hasSubscriptionWithAutorenewEnabled: Bool
        if let subscription = result.subscription {
            hasSubscriptionWithAutorenewEnabled = subscription.isActive() && subscription.isAutorenewEnabled
        } else {
            hasSubscriptionWithAutorenewEnabled = false
        }

        let purchaseSucceeded: Bool
        if result.transaction?.transactionState == .purchased {
            purchaseSucceeded = true
        } else {
            purchaseSucceeded = (result.transaction?.failedWithUnknownReason ?? false) && hasSubscriptionWithAutorenewEnabled
        }

        if purchaseSucceeded {

            var params: [String: AnyHashable] = ["rule_id": self.rule.id, "name": "$purchase", "screen_id": self.screenID]

            var properties = ["product_id": product.productIdentifier]

            if offerID != nil {
                apphudLog("Promo purchased with id: \(offerID!)", forceDisplay: true)
                properties["offer_id"] = offerID!
            } else {
                apphudLog("Product purchased with id: \(product.productIdentifier)", forceDisplay: true)
            }

            if let trx = result.transaction, trx.transactionState == .purchased, let transaction_id = trx.transactionIdentifier {
                properties["transaction_id"] = transaction_id
            }

            if let id = result.subscription?.id, id.count > 0 {
                properties["subscription_id"] = id
            }

            params["properties"] = properties

            ApphudInternal.shared.trackEvent(params: params) {}

            ApphudInternal.shared.uiDelegate?.apphudDidPurchase?(product: product, offerID: offerID, screenName: self.rule.screen_name)

            dismiss() // dismiss only when purchase is successful

        } else {
            stopLoading()
            isPurchasing = false
            apphudLog("Couldn't purchase with error:\(error?.localizedDescription ?? "")", forceDisplay: true)
            // if error occurred, restore subscriptions
            if !(errorCode == .paymentCancelled) {
                // maybe remove?
                Apphud.restorePurchases { _, _, _  in }
            }

            ApphudInternal.shared.uiDelegate?.apphudDidFailPurchase?(product: product, offerID: offerID, errorCode: errorCode, screenName: self.rule.screen_name)
        }
    }

    private func handlePostFeedbackTapped(urlComps: URLComponents) {
        self.webView.evaluateJavaScript("document.getElementById('text').textContent") { (result, _) in
            if let text = result as? String, let question = urlComps.queryItems?.first(where: { $0.name == "question" })?.value {
                if text.count > 0 {
                    self.startLoading()
                    ApphudInternal.shared.trackEvent(params: ["rule_id": self.rule.id, "screen_id": self.screenID, "name": "$feedback", "properties": ["question": question, "answer": text]]) {
                        self.thankForFeedbackAndClose(isSurvey: false)
                    }
                } else {
                    // tapped on send button with empty text view, do nothing
                }
            } else {
                apphudLog("Couldn't find text content in screen: \(self.screenID)", forceDisplay: true)
                self.dismiss()
            }
        }
    }
}
