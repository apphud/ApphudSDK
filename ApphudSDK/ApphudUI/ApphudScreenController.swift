//
//  ApphudScreenController.swift
//  Apphud, Inc
//
//  Created by ren6 on 26/08/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import UIKit
import WebKit
import StoreKit
import SafariServices

@available(iOS 11.2, *)
class ApphudScreenController: UIViewController {

    internal lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: self.view.bounds, configuration: config)
        wv.navigationDelegate = self
        self.view.addSubview(wv)
        wv.allowsLinkPreview = false
        wv.allowsBackForwardNavigationGestures = false
        wv.scrollView.layer.masksToBounds = false
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.isOpaque = false
        wv.scrollView.isOpaque = false
        wv.backgroundColor = UIColor.clear
        wv.scrollView.backgroundColor = UIColor.clear
        wv.scrollView.alwaysBounceVertical = false
        wv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: self.view.topAnchor),
            wv.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        return wv
    }()

    internal var isPurchasing = false
    internal var error: Error?
    internal var originalHTML: String?
    internal var macrosesMap = [[String: String]]()

    private(set) var rule: ApphudRule
    private(set) var screenID: String

    private var screen: ApphudScreen?
    private var addedObserver = false
    private var start = Date()
    private var loadedCallback: ((Bool) -> Void)?

    private var didAppear = false
    private var didLoadScreen = false
    private var handledDidAppearAndDidLoadScreen = false

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let loading = UIActivityIndicatorView(style: .gray)
        loading.hidesWhenStopped = true
        self.view.addSubview(loading)
        loading.translatesAutoresizingMaskIntoConstraints = false
        loading.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        loading.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        return loading
    }()

    override var preferredStatusBarStyle: UIStatusBarStyle {
        if self.screen?.status_bar_color == "white" {
            return .lightContent
        } else {
            return .default
        }
    }

    init(rule: ApphudRule, screenID: String, didLoadCallback: @escaping (Bool) -> Void) {
        self.rule = rule
        self.screenID = screenID
        self.loadedCallback = didLoadCallback
        super.init(nibName: nil, bundle: nil)
    }

    internal func loadScreenPage() {

        // if after 15 seconds webview not appeared, then fail
        self.perform(#selector(failedByTimeOut), with: nil, afterDelay: 15.0)
        self.startLoading()
        _ = self.view // trigger viewdidload
        self.webView.alpha = 0

        ApphudHttpClient.shared.loadScreenHtmlData(screenID: self.screenID) { (html, error) in
            if let html = html {
                self.originalHTML = html
                self.extractMacrosesUsingRegexp()
            } else {

                let apphud_error = ApphudError(message: "html is nil for rule id: \(self.rule.id), screen id: \(self.screenID), error:\( error?.localizedDescription ?? "")")

                self.failed(apphud_error)
            }
        }
    }

    @objc internal func editAndReloadPage(html: String) {
        let url = URL(string: ApphudHttpClient.shared.domainUrlString)
        self.webView.tag = 1
        self.webView.loadHTMLString(html as String, baseURL: url)
    }

    // MARK: - Private

    deinit {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(failedByTimeOut), object: nil)
        NotificationCenter.default.removeObserver(self)
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("Init with coder has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        didAppear = true
        if error != nil {
            apphudLog("Closing screen due to fatal error: \(error!) rule ID: \(self.rule.id) screen ID: \(self.screenID)", forceDisplay: true)
            dismiss()
        } else if didLoadScreen {
            handleDidAppearAndDidLoadScreen()
        }
    }

    private func handleDidAppearAndDidLoadScreen() {

        if handledDidAppearAndDidLoadScreen {return}
        handledDidAppearAndDidLoadScreen = true

        apphudLog("Screen is appeared: \(self.screenID)")

        self.getScreenInfo()
        self.preloadSurveyAnswerPages()
        self.handleScreenPresented()
        self.handleReadNotificationsOnce()
        ApphudInternal.shared.uiDelegate?.apphudScreenDidAppear?(screenName: rule.screen_name)
    }

    @objc private func failedByTimeOut() {
        failed(ApphudError(message: "Timeout error"))
    }

    @objc internal func failed(_ error: Error) {
        // for now just dismiss
        self.error = error
        apphudLog("Could not show screen with error: \(error)", forceDisplay: true)
        self.loadedCallback?(false)
        self.loadedCallback = nil
        self.dismiss()
    }

    private func getScreenInfo() {

        let js = "window.screenInfo"
        self.webView.evaluateJavaScript(js) { (result, _) in
            DispatchQueue.main.async {
                if let dict = result as? [String: Any] {
                    let screen = ApphudScreen(dictionary: dict)
                    self.screen = screen
                    self.navigationController?.setNeedsStatusBarAppearanceUpdate()
                    self.updateBackgroundColor()
                } else {
                    apphudLog("screen info not found in screen ID: \(self.screenID)", forceDisplay: true)
                }
            }
        }
    }

    private func preloadSurveyAnswerPages() {
        let js = """
                        function getScreenIds(){
                            var elems = [];
                            for (let elem of document.links){
                               if (elem.href.includes('/screen')){
                                    elems.push(elem.href);
                               }
                            }
                            return elems;
                        }
                        getScreenIds();
                """
        var screenIDS = [String]()

        self.webView.evaluateJavaScript(js) { (result, _) in
            if let array = result as? [String] {
                for url in array {
                    if let comps = URLComponents(string: url), let id = comps.queryItems?.first(where: { $0.name == "id" })?.value, !screenIDS.contains(id) {
                        screenIDS.append(id)
                    }
                }
            }
            if let nc = self.navigationController as? ApphudNavigationController {
                nc.preloadScreens(screenIDS: screenIDS, rule: self.rule)
            }
        }
    }

    private func updateBackgroundColor() {
        if self.screen?.status_bar_color == "white" {
            self.view.backgroundColor = UIColor.black
            self.loadingIndicator.style = .white
        } else {
            self.view.backgroundColor = UIColor.white
            self.loadingIndicator.style = .gray
        }
    }

    internal func addObserverIfNeeded() {
        if !addedObserver {
            NotificationCenter.default.addObserver(self, selector: #selector(replaceMacroses), name: Apphud.didFetchProductsNotification(), object: nil)
            addedObserver = true
        }
    }

    // MARK: - Handle Loader

    func startLoading() {
        self.webView.evaluateJavaScript("startLoader()") { (_, error) in
            if error != nil {
                self.loadingIndicator.startAnimating()
            }
        }
    }

    func stopLoading(error: Error? = nil) {
        self.loadingIndicator.stopAnimating()
        self.webView.evaluateJavaScript("stopLoader()") { (_, _) in
        }
    }

    // MARK: - Actions

    func handleScreenDidLoad() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(failedByTimeOut), object: nil)

        didLoadScreen = true

        webView.alpha = 1

        if didAppear {
            handleDidAppearAndDidLoadScreen()
        }

        stopLoading()
        loadedCallback?(true)
        loadedCallback = nil
    }

    internal func purchaseProduct(productID: String?, offerID: String?) {

        guard let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == productID}) else {
            apphudLog("Aborting purchase because couldn't find product with id: \(productID ?? "")", forceDisplay: true)
            return
        }

        if offerID != nil {
            if #available(iOS 12.2, *) {
                if product.discounts.first(where: {$0.identifier == offerID!}) != nil {

                    if isPurchasing {return}
                    isPurchasing = true
                    self.startLoading()

                    ApphudInternal.shared.uiDelegate?.apphudWillPurchase?(product: product, offerID: offerID!, screenName: self.rule.screen_name)

                    ApphudInternal.shared.purchasePromo(product: product, discountID: offerID!) { (result) in
                        self.handlePurchaseResult(product: product, offerID: offerID!, result: result)
                    }
                } else {
                    apphudLog("Aborting purchase because couldn't find promo offer with id: \(offerID!) in product: \(product.productIdentifier), available promo offer ids: \(product.apphudPromoIdentifiers())", forceDisplay: true)
                }
            } else {
                apphudLog("Aborting purchase because promotional offers are available only on iOS 12.2 and above", forceDisplay: true)
            }
        } else {

            if isPurchasing {return}
            isPurchasing = true
            self.startLoading()

            ApphudInternal.shared.uiDelegate?.apphudWillPurchase?(product: product, offerID: nil, screenName: self.rule.screen_name)
            
            ApphudInternal.shared.purchase(product: product) { (result) in
                self.handlePurchaseResult(product: product, result: result)
            }
        }
    }

    internal func closeTapped() {
        dismiss()
    }

    internal func dismiss() {

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(failedByTimeOut), object: nil)

        if !didAppear {return}

        let supportBackNavigation = false

        let presentedVC = (self.navigationController ?? self)

        ApphudInternal.shared.uiDelegate?.apphudScreenWillDismiss?(screenName: rule.screen_name, error: error)

        if let nc = navigationController, nc.viewControllers.count > 1 && supportBackNavigation {
            nc.popViewController(animated: true)
        } else {
            presentedVC.dismiss(animated: true) {
                if let nc = presentedVC as? ApphudNavigationController {
                    nc.handleDidDismiss()
                }
            }
        }
    }

    internal func restoreTapped() {
        self.startLoading()
        Apphud.restorePurchases { subscriptions, _, _ in
            self.stopLoading()
            if subscriptions?.first?.isActive() ?? false {
                self.dismiss()
            }
        }
    }

    internal func thankForFeedbackAndClose(isSurvey: Bool) {

        let message = isSurvey ? "Answer sent" : "Feedback sent"

        let alertController = UIAlertController(title: "Thank you for feedback!", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { (_) in
            self.dismiss()
        }))
        present(alertController, animated: true, completion: nil)
    }

    internal func handleBillingIssueTapped() {
        ApphudInternal.shared.trackEvent(params: ["rule_id": self.rule.id, "screen_id": self.screenID, "name": "$billing_issue"]) {}
        self.dismiss()
        if let url = URL(string: "https://apps.apple.com/account/billing"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
}
