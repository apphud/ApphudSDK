//
//  ApphudScreenController.swift
//  apphud
//
//  Created by Renat on 26/08/2019.
//  Copyright © 2019 softeam. All rights reserved.
//

import UIKit
import WebKit
import StoreKit
import SafariServices

@available(iOS 11.2, *)
class ApphudScreenController: UIViewController{
    
    private lazy var webView : WKWebView = { 
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: self.view.bounds, configuration: config)
        wv.navigationDelegate = self
        self.view.addSubview(wv)
        wv.allowsLinkPreview = false
        wv.allowsBackForwardNavigationGestures = false
        wv.scrollView.layer.masksToBounds = false
        wv.scrollView.contentInsetAdjustmentBehavior = .never;
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
            wv.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
        return wv
    }()
        
    override var preferredStatusBarStyle: UIStatusBarStyle {
        if self.screen?.status_bar_color == "white" {
            return .lightContent
        } else {
            return .default
        }
    }
    
    private(set) var rule: ApphudRule
    private(set) var screenID: String
    
    private var screen: ApphudScreen?
    private var addedObserver = false
    private var isPurchasing = false
    private var start = Date()
    private var error : Error?
    private var loadedCallback: ((Bool) -> Void)?
    private var originalHTML: String?
    private var macrosesMap = [[String : String]]()
    private var didAppear = false
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
    
    init(rule: ApphudRule, screenID: String, didLoadCallback: @escaping (Bool) -> Void) {
        self.rule = rule
        self.screenID = screenID
        self.loadedCallback = didLoadCallback
        super.init(nibName: nil, bundle: nil)
    }
    
    internal func loadScreenPage(){
                            
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
                let apphud_error = ApphudError.error(message: "html is nil for rule id: \(self.rule.id), screen id: \(self.screenID), error:\( error?.localizedDescription ?? "")")
                self.failed(apphud_error)
            }
        }        
    }
    
    @objc private func editAndReloadPage(html: String){        
        let url = URL(string: ApphudHttpClient.shared.domain_url_string)
        self.webView.tag = 1
        self.webView.loadHTMLString(html as String, baseURL: url)
    }
    
    //MARK:- Private
    
    deinit {
//        apphudLog("Deinit ApphudScreenController(\(screenID))")
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
        } else if self.webView.tag == 1 {
            handleDidAppearAndDidLoadScreen()
        }
    }
    
    private func handleDidAppearAndDidLoadScreen(){
        
        if handledDidAppearAndDidLoadScreen {return}
        handledDidAppearAndDidLoadScreen = true
        
        apphudLog("Screen is appeared: \(self.screenID)")
        
        self.getScreenInfo()
        self.preloadSurveyAnswerPages()
        self.handleScreenPresented()
        self.handleReadNotificationsOnce()
    }
    
    @objc private func failedByTimeOut(){
        failed(ApphudError.error(message: "Timeout error"))
    }
    
    @objc private func failed(_ error: Error){
        // for now just dismiss
        self.error = error
        apphudLog("Could not show screen with error: \(error)", forceDisplay: true)
        self.loadedCallback?(false)
        self.loadedCallback = nil
        self.dismiss()
    }
    
    private func getScreenInfo(){
                
        let js = "window.screenInfo"
        self.webView.evaluateJavaScript(js) { (result, error) in
            DispatchQueue.main.async {
                if let dict = result as? [String : Any] {
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

    private func preloadSurveyAnswerPages(){
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
        
        self.webView.evaluateJavaScript(js) { (result, error) in
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
    
    private func updateBackgroundColor(){
        if self.screen?.status_bar_color == "white" {
            self.view.backgroundColor = UIColor.black
            self.loadingIndicator.style = .white
        } else {
            self.view.backgroundColor = UIColor.white
            self.loadingIndicator.style = .gray
        }
    }
    
    private func addObserverIfNeeded(){
        if !addedObserver {
            NotificationCenter.default.addObserver(self, selector: #selector(replaceMacroses), name: Apphud.didFetchProductsNotification(), object: nil)
            addedObserver = true
        }
    }
    
    //MARK:- Handle Loader
    
    func startLoading(){
        self.webView.evaluateJavaScript("startLoader()") { (result, error) in
            if error != nil {
                self.loadingIndicator.startAnimating()
            }
        }
    }
    
    func stopLoading(error: Error? = nil){
        self.loadingIndicator.stopAnimating()
        self.webView.evaluateJavaScript("stopLoader()") { (result, error) in
        }
    }
    
    //MARK:- Handle Macroses
    
    func replaceStringFor(product: SKProduct, offerID : String? = nil) -> String {
        if offerID != nil {
            if #available(iOS 12.2, *) {
                if let discount = product.discounts.first(where: {$0.identifier == offerID!}) {
                    return product.localizedDiscountPrice(discount: discount)
                } else {
                    apphudLog("Couldn't find promo offer with id: \(offerID!) in product: \(product.productIdentifier)", forceDisplay: true)
                    return ""
                }
            } else {
                apphudLog("Promo offers are not available under iOS 12.2, offerID: \(offerID!) in product: \(product.productIdentifier)", forceDisplay: true)
                return ""
            }            
        } else {
            return product.localizedPrice()
        }
    }
    
    func extractMacrosesUsingRegexp(){
        
        guard self.originalHTML != nil else {return}
        let scanner = Scanner(string: self.originalHTML!)
        
        var shouldScan = true
        
        var macroses = [String]()
        
        while shouldScan {
            var tempString : NSString?
            scanner.scanUpTo("{{\"", into: &tempString)           
            if tempString != nil {
                scanner.scanUpTo("}}", into: &tempString)
                if scanner.isAtEnd {
                    shouldScan = false
                } else {
                    macroses.append("\(tempString as String? ?? "")}}")
                }
            } else {
                shouldScan = false
            }
        }
        
        var productsOffersMap = [[String : String]]()
        
        for macros in macroses {
            let scanner = Scanner(string: macros)
            var tempString : NSString?
            
            var dict = [String : String]()
            dict["macros"] = macros
            if scanner.scanUpTo("\"", into: &tempString) && !scanner.isAtEnd {
                scanner.scanLocation = scanner.scanLocation + 1
                scanner.scanUpTo("\"", into: &tempString)
                
                if let product_id = tempString as String? {
                    dict["product_id"] = product_id
                }
                
                if scanner.scanUpTo("price: \"", into: &tempString) && !scanner.isAtEnd {
                    scanner.scanLocation = scanner.scanLocation + 8
                    scanner.scanUpTo("\"", into: &tempString)
                    if let offer_id = (tempString as String?){
                        dict["offer_id"] = offer_id
                    }   
                }       
            }
            productsOffersMap.append(dict)
        }

        self.macrosesMap = productsOffersMap
        
        // replace macroses
        self.replaceMacroses()
    }
    
    @objc func replaceMacroses(){
        
        if ApphudStoreKitWrapper.shared.products.count == 0 {
            addObserverIfNeeded()
            return
        }
        
        var html : NSString = self.originalHTML! as NSString
        
        for macrosDict in self.macrosesMap {
            
            guard let macros = macrosDict["macros"] else { continue }
            
            var replace_string = ""
            
            if let product_id = macrosDict["product_id"], let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == product_id}) {
                if let offer_id = macrosDict["offer_id"]  {
                    replace_string = replaceStringFor(product: product, offerID: offer_id) 
                } else {
                    replace_string = replaceStringFor(product: product)
                }
            }
             
            html = html.replacingOccurrences(of: macros, with: replace_string) as NSString
        }
        
        self.editAndReloadPage(html: html as String)
    }
    
    //MARK:- Actions
    
    func handleScreenDidLoad(){
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(failedByTimeOut), object: nil)
        
        webView.alpha = 1
        let date = Date().timeIntervalSince(start)
        apphudLog("screen final load time: \(date)")
        
        if didAppear {
            handleDidAppearAndDidLoadScreen()
        }
        
        stopLoading()
        loadedCallback?(true)
        loadedCallback = nil
    }
    
    private func purchaseProduct(productID: String?, offerID: String?) {
                
        guard let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == productID}) else {
            apphudLog("Aborting purchase because couldn't find product with id: \(productID ?? "")", forceDisplay: true)
            return
        }
                   
        if offerID != nil {
            
            if #available(iOS 12.2, *), product.discounts.first(where: {$0.identifier == offerID!}) != nil {
                
                if isPurchasing {return}
                isPurchasing = true
                self.startLoading()
                
                ApphudInternal.shared.uiDelegate?.apphudWillPurchase?(product: product, offerID: offerID!, screenName: self.screen?.name ?? "unknown")
                
                ApphudInternal.shared.purchasePromo(product: product, discountID: offerID!) { (subscription, transaction, error) in
                    self.handlePurchaseResult(product: product, offerID: offerID!, subscription: subscription, transaction: transaction, error: error)                    
                }
            } else {
                apphudLog("Aborting purchase because couldn't find promo offer with id: \(offerID!) in product: \(product.productIdentifier)", forceDisplay: true)
                return
            }
            
        } else {
            
            if isPurchasing {return}
            isPurchasing = true
            self.startLoading()
            
            ApphudInternal.shared.uiDelegate?.apphudWillPurchase?(product: product, offerID: nil, screenName: self.screen?.name ?? "unknown")
            
            ApphudInternal.shared.purchase(product: product) { (subscription, transaction, error) in
                self.handlePurchaseResult(product: product, subscription: subscription, transaction: transaction, error: error)
            }
        }
    }
    
    private func closeTapped(){
        dismiss()
    }
    
    private func dismiss(){   
                
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(failedByTimeOut), object: nil)
        
        if !didAppear {return}
        
        let supportBackNavigation = false
        
        let presentedVC = (self.navigationController ?? self)

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
    
    private func restoreTapped(){
        self.startLoading()
        Apphud.restoreSubscriptions { subscriptions in
            self.stopLoading()
            if subscriptions?.first?.isActive() ?? false {
                self.dismiss()
            }
        }
    }
    
    private func thankForFeedbackAndClose(isSurvey: Bool){
        
        let message = isSurvey ? "Answer sent" : "Feedback sent"
        
        let alertController = UIAlertController(title: "Thank you for feedback!", message: message, preferredStyle: .alert)
        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            self.dismiss()
        }))
        present(alertController, animated: true, completion: nil)
    }
}



// MARK:- WKNavigationDelegate delegate

@available(iOS 11.2, *)
extension ApphudScreenController : WKNavigationDelegate {
    
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
        if handleNavigationAction(navigationAction: navigationAction){
            decisionHandler(.allow)
        } else {
            decisionHandler(.cancel)
        }
    }
}

// MARK:- Handle Events

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
    
    private func handleLink(url: URL){
        
        let urlComps = URLComponents(url: url, resolvingAgainstBaseURL: true)
        
        guard let urlString = urlComps?.queryItems?.first(where: { $0.name == "url" })?.value else {
            return
        }
        
        guard let navigationURL = URL(string: urlString) else {
            return
        }

        if UIApplication.shared.canOpenURL(navigationURL){
            let controller = SFSafariViewController(url: navigationURL)
            controller.modalPresentationStyle = self.navigationController?.modalPresentationStyle ?? .fullScreen
            present(controller, animated: true, completion: nil)
        }
    }
    
    private func handleReadNotificationsOnce(){
        // perform only for initial screen in view controllers stack
        if self == navigationController?.viewControllers.first {
            ApphudInternal.shared.readAllNotifications(for: self.rule.id)
        }
    }
    
    private func handleScreenPresented(){
        ApphudInternal.shared.trackEvent(params: ["rule_id" : self.rule.id, "screen_id" : self.screenID, "name" : "$screen_presented"]) {}
    }
    
    private func handleSurveyAnswer(urlComps: URLComponents, answerAndDismiss: Bool){
        
        let question = urlComps.queryItems?.first(where: { $0.name == "question" })?.value
        let answer = urlComps.queryItems?.first(where: { $0.name == "answer" })?.value
        
        if question != nil && answer != nil {
            ApphudInternal.shared.trackEvent(params: ["rule_id" : self.rule.id, "screen_id" : self.screenID, "name" : "$survey_answer", "properties" : ["question" : question!, "answer" : answer!]]) {}            
        }
        
        if answerAndDismiss {
            thankForFeedbackAndClose(isSurvey: true)
        }
    }
    
    private func handleBillingIssueTapped(){
        ApphudInternal.shared.trackEvent(params: ["rule_id" : self.rule.id, "screen_id" : self.screenID, "name" : "$billing_issue"]) {}
        self.dismiss()
        if let url = URL(string: "https://apps.apple.com/account/billing"), UIApplication.shared.canOpenURL(url) {
            UIApplication.shared.open(url, options: [:], completionHandler: nil)
        }
    }
    
    private func handlePurchaseResult(product: SKProduct, offerID: String? = nil, subscription: ApphudSubscription?, transaction: SKPaymentTransaction?, error: Error?) {
            
        var errorCode : SKError.Code = .unknown
        
        if let skError = error as? SKError {
            errorCode = skError.code
        }
        
        let isActive = subscription?.isActive() ?? false
        let productIDChanged = subscription?.productId != product.productIdentifier
        
        let shouldSubmitPurchaseEvent = error == nil || (isActive && !(errorCode == .paymentCancelled) && (offerID != nil || productIDChanged))
        
        if shouldSubmitPurchaseEvent {
            
            var params : [String : AnyHashable] = ["rule_id" : self.rule.id, "name" : "$purchase", "screen_id" : self.screenID]
            
            var properties = ["product_id" : product.productIdentifier]
            
            if offerID != nil {   
                apphudLog("Promo purchased with id: \(offerID!)", forceDisplay: true)
                properties["offer_id"] = offerID!
            } else {
                apphudLog("Product purchased with id: \(product.productIdentifier)", forceDisplay: true)
            }
            
            if let trx = transaction, trx.transactionState == .purchased, let transaction_id = trx.transactionIdentifier {
                properties["transaction_id"] = transaction_id
            }
            
            if let id = subscription?.id, id.count > 0 {
                properties["subscription_id"] = id
            }
            
            params["properties"] = properties
            
            ApphudInternal.shared.trackEvent(params: params) {}
            
            ApphudInternal.shared.uiDelegate?.apphudDidPurchase?(product: product, offerID: offerID, screenName: self.screen?.name ?? "unknown")
            
            dismiss() // dismiss only when purchase is successful
            
        } else {        
            stopLoading()
            isPurchasing = false
            apphudLog("Couldn't purchase with error:\(error?.localizedDescription ?? "")", forceDisplay: true)
            // if error occurred, restore subscriptions
            if !(errorCode == .paymentCancelled) {
                // maybe remove?
                Apphud.restoreSubscriptions { subscriptions in }
            }
            
            ApphudInternal.shared.uiDelegate?.apphudDidFailPurchase?(product: product, offerID: offerID, errorCode: errorCode, screenName: self.screen?.name ?? "unknown")
        }
    }
    
    private func handlePostFeedbackTapped(urlComps: URLComponents){
        self.webView.evaluateJavaScript("document.getElementById('text').textContent") { (result, error) in
            if let text = result as? String, let question = urlComps.queryItems?.first(where: { $0.name == "question" })?.value {
                if text.count > 0 {
                    self.startLoading()
                    ApphudInternal.shared.trackEvent(params: ["rule_id" : self.rule.id, "screen_id" : self.screenID, "name" : "$feedback", "properties" : ["question" : question, "answer" : text]]) { 
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
