//
//  ApphudScreenController.swift
//  Apphud, Inc
//
//  Created by ren6 on 26/08/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#endif
#if canImport(WebKit)
import WebKit
#endif
#if canImport(SafariServices)
import SafariServices
#endif
import StoreKit

#if os(iOS)

/// Forwarder to avoid retain cycle: WKUserContentController strongly retains the script message handler.
private final class ApphudScreenReadyMessageHandler: NSObject, WKScriptMessageHandler {
    weak var controller: ApphudScreenController?
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        controller?.handleScreenDidLoad()
    }
}

class ApphudScreenController: UIViewController {

    /// Navigation from our main loadHTMLString; used so didFinish/didFail are tied to our load, not webView.tag (which client app may overwrite).
    var pendingScreenLoadNavigation: WKNavigation?

    private var screenReadyMessageHandler: ApphudScreenReadyMessageHandler?

    internal lazy var webView: WKWebView = {
        let config = WKWebViewConfiguration()
        let handler = ApphudScreenReadyMessageHandler()
        config.userContentController.add(handler, name: "apphudScreenReady")
        self.screenReadyMessageHandler = handler
        handler.controller = self
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

    private(set) var screen: ApphudRuleScreen?
    private var addedObserver = false
    private var start = Date()
    private var loadedCallback: ((Bool) -> Void)?

    private var didAppear = false
    private var didLoadScreen = false
    private var handledDidAppearAndDidLoadScreen = false

    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let loading = UIActivityIndicatorView(style: .medium)
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
        // if after 30 seconds webview not appeared, then fail
        self.perform(#selector(failedByTimeOut), with: nil, afterDelay: 30.0)
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

    private static let screenReadyScript = "<script>try{window.webkit.messageHandlers.apphudScreenReady.postMessage('ready');}catch(e){}</script>"

    /// `true` when presented as a sheet (`.automatic` / pageSheet / formSheet, etc.),
    /// `false` for `.fullScreen` / `.overFullScreen`.
    private var isSheetPresentation: Bool {
        let style = navigationController?.modalPresentationStyle ?? modalPresentationStyle
        switch style {
        case .fullScreen, .overFullScreen:
            return false
        default:
            return true
        }
    }

    private var presentationClassName: String {
        isSheetPresentation ? "aph-sheet" : "aph-fullscreen"
    }

    /// Injected early so templates can style close-button offsets before first paint.
    /// Use in CSS: `html.aph-sheet .screen-…__close { top: 20px; }`
    /// and `html.aph-fullscreen .screen-…__close { top: calc(20px + env(safe-area-inset-top, 0px)); }`
    private func presentationBootstrapScript() -> String {
        let className = presentationClassName
        return """
        <script>
        (function(){
          var c='\(className)';
          function apply(){
            var r=document.documentElement;
            if(!r) return;
            r.classList.remove('aph-sheet','aph-fullscreen');
            r.classList.add(c);
            if(document.body){
              document.body.classList.remove('aph-sheet','aph-fullscreen');
              document.body.classList.add(c);
            }
          }
          apply();
          document.addEventListener('DOMContentLoaded', apply);
        })();
        </script>
        """
    }

    private func applyPresentationClassToWebView() {
        let className = presentationClassName
        let js = """
        (function(){
          var c='\(className)';
          var r=document.documentElement;
          if(!r) return;
          r.classList.remove('aph-sheet','aph-fullscreen');
          r.classList.add(c);
          if(document.body){
            document.body.classList.remove('aph-sheet','aph-fullscreen');
            document.body.classList.add(c);
          }
        })();
        """
        webView.evaluateJavaScript(js, completionHandler: nil)
    }

    @objc internal func editAndReloadPage(html: String) {
        self.webView.tag = 1
        var htmlToLoad = html
        let bootstrap = presentationBootstrapScript()
        if let regex = try? NSRegularExpression(pattern: "<head[^>]*>", options: .caseInsensitive),
           let match = regex.firstMatch(in: htmlToLoad, range: NSRange(htmlToLoad.startIndex..., in: htmlToLoad)),
           let range = Range(match.range, in: htmlToLoad) {
            htmlToLoad.replaceSubrange(range, with: htmlToLoad[range] + bootstrap)
        } else {
            htmlToLoad = bootstrap + htmlToLoad
        }
        if htmlToLoad.contains("</body>") {
            htmlToLoad = htmlToLoad.replacingOccurrences(of: "</body>", with: Self.screenReadyScript + "</body>")
        } else {
            htmlToLoad += Self.screenReadyScript
        }
        self.pendingScreenLoadNavigation = self.webView.loadHTMLString(htmlToLoad, baseURL: nil)
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
        applyPresentationClassToWebView()
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

        applyPresentationClassToWebView()
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
                    let screen = ApphudRuleScreen(dictionary: dict)
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
            self.loadingIndicator.style = .medium
        } else {
            self.view.backgroundColor = UIColor.white
            self.loadingIndicator.style = .medium
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
        guard !didLoadScreen else {
            return
        }
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(failedByTimeOut), object: nil)

        didLoadScreen = true
        pendingScreenLoadNavigation = nil

        applyPresentationClassToWebView()
        webView.alpha = 1

        if didAppear {
            handleDidAppearAndDidLoadScreen()
        }

        stopLoading()
        loadedCallback?(true)
        loadedCallback = nil
    }

    internal func purchaseProduct(productID: String?, offerID: String?) {

        guard let productID else {
            apphudLog("Aborting purchase because product id is missing", forceDisplay: true)
            return
        }

        // The SK1 products cache is filled by a best-effort background feeder now, so the
        // product may not be there yet — fetch it once on demand instead of aborting.
        // The fetched product is used directly: the cache is not written by this fetch,
        // so re-entering through it would loop forever.
        guard let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == productID}) else {
            if isPurchasing { return }
            isPurchasing = true
            self.startLoading()
            Task { @MainActor [weak self] in
                let fetched = await ApphudStoreKitWrapper.shared.fetchProduct(productID)
                guard let self else { return }
                // Hand the loading state over to startPurchase without a visible flicker.
                self.isPurchasing = false
                guard self.view.window != nil else {
                    self.stopLoading()
                    return // screen was closed meanwhile
                }
                if let fetched {
                    self.startPurchase(product: fetched, offerID: offerID)
                } else {
                    self.stopLoading()
                    apphudLog("Aborting purchase because couldn't find product with id: \(productID)", forceDisplay: true)
                    ApphudInternal.shared.uiDelegate?.apphudDidFailPurchase?(productId: productID, offerID: offerID, error: ApphudError(message: "Product not found: \(productID)"), screenName: self.rule.screen_name)
                }
            }
            return
        }

        startPurchase(product: product, offerID: offerID)
    }

    private func startPurchase(product: SKProduct, offerID: String?) {

        if offerID != nil && offerID!.count > 0 {
                if product.discounts.first(where: {$0.identifier == offerID!}) != nil {

                    if isPurchasing {return}
                    isPurchasing = true
                    self.startLoading()

                    ApphudInternal.shared.uiDelegate?.apphudWillPurchase?(product: product, offerID: offerID!, screenName: self.rule.screen_name)
                    ApphudInternal.shared.uiDelegate?.apphudWillPurchase?(productId: product.productIdentifier, offerID: offerID!, screenName: self.rule.screen_name)

                    ApphudInternal.shared.purchasePromo(productId: product.productIdentifier, apphudProduct: nil, discountID: offerID!, fromScreen: true) { (result) in
                        self.handlePurchaseResult(product: product, offerID: offerID!, result: result)
                    }
                } else {
                    apphudLog("Aborting purchase because couldn't find promo offer with id: \(offerID!) in product: \(product.productIdentifier), available promo offer ids: \(product.apphudPromoIdentifiers())", forceDisplay: true)
                }
        } else {

            if isPurchasing {return}
            isPurchasing = true
            self.startLoading()

            ApphudInternal.shared.uiDelegate?.apphudWillPurchase?(product: product, offerID: nil, screenName: self.rule.screen_name)
            ApphudInternal.shared.uiDelegate?.apphudWillPurchase?(productId: product.productIdentifier, offerID: nil, screenName: self.rule.screen_name)

            ApphudInternal.shared.purchase(productId: product.productIdentifier, product: nil, validate: true, purchasingFromScreen: true) { result in
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

        ApphudInternal.shared.uiDelegate?.apphudScreenWillDismiss?(screenName: screen?.name ?? rule.screen_name, error: error)

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
        Apphud.restorePurchases { _ in
            self.stopLoading()
            if Apphud.hasPremiumAccess() {
                self.dismiss()
            }
        }
    }

    internal func thankForFeedbackAndClose(isSurvey: Bool) {

        let action = ApphudInternal.shared.uiDelegate?.apphudScreenDismissAction?(screenName: screen?.name ?? rule.screen_name, controller: self) ?? .thankAndClose

        switch action {
        case .thankAndClose:
            thankAndClose(isSurvey: isSurvey)
        case .closeOnly:
            dismiss()
        case .none:
            break
        }
    }

    private func thankAndClose(isSurvey: Bool) {
        let message = isSurvey ? "Answer sent" : "Feedback sent"
        let alertController = UIAlertController(title: "Thank you for feedback!", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
            self?.dismiss()
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
#endif
