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
    
    override var preferredStatusBarStyle: UIStatusBarStyle{
        if self.screen?.status_bar_color == "white" {
            return .lightContent
        } else {
            return .default
        }
    }
    
    private var rule: ApphudRule
    private var option: ApphudRuleOption
    
    private var screen: ApphudScreen?
    private var addedObserver = false
    private var isPurchasing = false
    private var start = Date()
    private var error : Error?
    
    private lazy var loadingIndicator: UIActivityIndicatorView = {
        let loading = UIActivityIndicatorView(style: .gray)
        loading.hidesWhenStopped = true
        self.view.addSubview(loading)
        loading.translatesAutoresizingMaskIntoConstraints = false
        loading.centerXAnchor.constraint(equalTo: self.view.centerXAnchor).isActive = true
        loading.centerYAnchor.constraint(equalTo: self.view.centerYAnchor).isActive = true
        return loading
    }()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    init(rule: ApphudRule, option: ApphudRuleOption) {
        self.rule = rule
        self.option = option
        super.init(nibName: nil, bundle: nil)
    }
       
    required init?(coder aDecoder: NSCoder) {
        fatalError("Init with coder has not been implemented")
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        self.view.backgroundColor = UIColor.white
        // if after 10 seconds webview not appeared, then fail
        self.perform(#selector(failedByTimeOut), with: nil, afterDelay: 15.0)
        self.loadScreenPage()
        self.startLoading()
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(true)
        if error != nil {
            apphudLog("Closing screen due to fatal error: \(error!) option id: \(option.id)", forceDisplay: true)
            dismiss()
        }
    }
    
    @objc private func failedByTimeOut(){
        failed(ApphudError.error(message: "Timeout error"))
    }
    
    @objc private func failed(_ error: Error){
        // for now just dismiss
        self.error = error
        apphudLog("Could not show screen with error: \(error)", forceDisplay: true)
        self.dismiss()
    }
    
    private func loadScreenPage(){
        if let screenID = self.option.screenID, let request = ApphudHttpClient.shared.makeScreenRequest(screenID: screenID) {   
            apphudLog("started loading page:\(request)")
            self.webView.alpha = 0
            self.webView.load(request)
        } else {
            let error = ApphudError.error(message: "screen ID not found in option: \(self.option.id)")
            failed(error)
        }
    }
    
    private func getScreenInfo(){
        
        let js = "window.screenInfo"
        self.webView.evaluateJavaScript(js) { (result, error) in
            DispatchQueue.main.async {
                if let dict = result as? [String : Any] {
                    let screen = ApphudScreen(dictionary: dict)
                    self.screen = screen
                    self.setNeedsStatusBarAppearanceUpdate()
                    self.updateBackgroundColor()
                    self.updatePage()
                } else {
                    let error = ApphudError.error(message: "screen info not found in template: \(self.option.screenID ?? "")")
                    self.failed(error)
                }
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
    
    @objc private func updatePage(){    
        let anyProductID = self.screen!.products_offers_map?.first?["product_id"] as? String
        let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == anyProductID})
        
        if ApphudStoreKitWrapper.shared.products.count > 0 && product == nil {
            let error = ApphudError.error(message: "Couldn't find product with id: \(anyProductID ?? "")")
            self.failed(error)
            return
        } 
        
        guard product != nil else {
            if !addedObserver {
                NotificationCenter.default.addObserver(self, selector: #selector(updatePage), name: ApphudStoreKitProductsFetched, object: nil)
                addedObserver = true
            }
            return
        }
                
        webView.evaluateJavaScript("document.documentElement.outerHTML") { (result, error) in
            if var html = result as? NSString {

                html = self.replaceMacroses(html: html)
                self.webView.tag = 1                
                
                let url = URL(string: ApphudHttpClient.shared.domain_url_string)
                
                self.webView.loadHTMLString(html as String, baseURL: url)
            } else {
                let error = ApphudError.error(message: "html is nil in: \(self.webView.url?.absoluteString ?? "")")
                self.failed(error)
            }
        }
    }
    
    //MARK:- Handle Loader
    
    func startLoading(){
        self.loadingIndicator.startAnimating()
//        self.webView.evaluateJavaScript("purchase_started();", completionHandler: nil)
    }
    
    func stopLoading(error: Error? = nil){
        self.loadingIndicator.stopAnimating()
//        if error != nil {
//            self.webView.evaluateJavaScript("purchase_failed();", completionHandler: nil)
//        } else {
//            self.webView.evaluateJavaScript("purchase_completed();", completionHandler: nil)
//        }
//        
    }
    
    //MARK:- Handle Macroses
    
    func macrosStringFor(product : SKProduct, offerID : String? = nil) -> String {
        if offerID != nil {
            return "{{\"\(product.productIdentifier)\" | price: \"\(offerID!)\"}}"
        } else {
            return "{{\"\(product.productIdentifier)\" | price}}"
        }
    }
    
    func replaceStringFor(product: SKProduct, offerID : String? = nil) -> String {
        if offerID != nil {
            if #available(iOS 12.2, *), let discount = product.discounts.first(where: {$0.identifier == offerID!}) {
                return product.localizedDiscountPrice(discount: discount)
            } else {
                apphudLog("Couldn't find promo offer with id: \(offerID!) in product: \(product.productIdentifier)", forceDisplay: true)
                return ""
            }
        } else {
            return product.localizedPrice()
        }
    }
    
    func replaceMacroses(html: NSString) -> NSString {
        let firstDiv = html.range(of: "<div")
        var searchStart = 0
        if firstDiv.location != NSNotFound {                        
            searchStart = firstDiv.location
        }
        var newHtml = html
                  
        for map in self.screen?.products_offers_map ?? [] {
            let product_id = map["product_id"] as? String
            let offer_id = map["offer_id"] as? String
            
            if let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == product_id}){
                
                if offer_id != nil {
                    let offer_macros = macrosStringFor(product: product, offerID: offer_id)
                    let offer_replace_string = replaceStringFor(product: product, offerID: offer_id)
                    newHtml = newHtml.replacingOccurrences(of: offer_macros, with: offer_replace_string, options: [], range: NSMakeRange(searchStart, newHtml.length - searchStart)) as NSString
                }
                
                let product_macros = macrosStringFor(product: product)
                let product_replace_string = replaceStringFor(product: product)
                newHtml = newHtml.replacingOccurrences(of: product_macros, with: product_replace_string, options: [], range: NSMakeRange(searchStart, newHtml.length - searchStart)) as NSString
            }
        }
        
        let searchUnreplacedMarcoses = newHtml.range(of: " | price")
        if searchUnreplacedMarcoses.location != NSNotFound {
            apphudLog("Couldn't replace all macroses. Please make sure you set up macroses correctly at Apphud Screen Constructor.", forceDisplay: true)
        }
        
        return newHtml
    }
    
    //MARK:- Actions
    
    func makeVisible(){
        let date = Date().timeIntervalSince(start)
        apphudLog("exec time: \(date)")
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(failedByTimeOut), object: nil)
        webView.alpha = 1
        self.stopLoading()
    }
    
    private func purchaseTapped(url: URL?){

        guard let url = url else {
            return
        }
        
        let urlComps = URLComponents(url: url, resolvingAgainstBaseURL: true)
        let productID = urlComps?.queryItems?.first(where: { $0.name == "product_id" })?.value
        
        guard let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == productID}) else {
            return
        }
        
        let offerID = urlComps?.queryItems?.first(where: { $0.name == "offer_id" })?.value
                   
        if offerID != nil {
            
            if #available(iOS 12.2, *), product.discounts.first(where: {$0.identifier == offerID!}) != nil {
                
                if isPurchasing {return}
                isPurchasing = true
                self.startLoading()
                Apphud.purchasePromo(product: product, discountID: offerID!) { (subscription, error) in
                    self.handlePurchaseResult(product: product, offerID: offerID!, subscription: subscription, error: error)
                }
            } else {
                apphudLog("Aborting purchase because couldn't find promo offer with id: \(offerID!) in product: \(product.productIdentifier)", forceDisplay: true)
                return
            }
            
        } else {
            
            if isPurchasing {return}
            isPurchasing = true
            self.startLoading()
            Apphud.purchase(product: product) { (subscription, error) in
                self.handlePurchaseResult(product: product, subscription: subscription, error: error)
            }
        }
    }
    
    private func handlePurchaseResult(product: SKProduct, offerID: String? = nil, subscription: ApphudSubscription?, error: Error?) {
        self.stopLoading(error: error)
        self.isPurchasing = false                    
        if subscription != nil {
            if offerID != nil {
                apphudLog("Promo purchased with id: \(offerID!)", forceDisplay: true)                
                ApphudInternal.shared.trackRuleEvent(ruleID: self.rule.id, params: ["kind" : "offer_activated", "option_id" : self.option.id, "product_id" : product.productIdentifier, "offer_id" : offerID!, "screen_id" : self.option.screenID!]) {}
            } else {
                apphudLog("Product purchased with id: \(product.productIdentifier)", forceDisplay: true)
                ApphudInternal.shared.trackRuleEvent(ruleID: self.rule.id, params: ["kind" : "product_purchased", "option_id" : self.option.id, "product_id" : product.productIdentifier, "screen_id" : self.option.screenID!]) {}
            }
            self.dismiss()
        } else {
            apphudLog("Couldn't purchase error:\(error?.localizedDescription ?? "")", forceDisplay: true)
            // if error occurred, restore subscriptions
            Apphud.restoreSubscriptions { subscriptions in
                
            }
        }
    }
    
    private func closeTapped(){
        dismiss()
    }
    
    private func dismiss(){   
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(failedByTimeOut), object: nil)
        (self.navigationController ?? self).dismiss(animated: true, completion: nil)
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
    
    private func openURL(url: URL?){
        guard let url = url else {
            return
        }
        
        let urlComps = URLComponents(url: url, resolvingAgainstBaseURL: true)
        
        guard let urlString = urlComps?.queryItems?.first(where: { $0.name == "url" })?.value else {
            return
        }        
        guard let navigationURL = URL(string: urlString) else {
            return
        }

        if UIApplication.shared.canOpenURL(navigationURL){
            let controller = SFSafariViewController(url: navigationURL)
            present(controller, animated: true, completion: nil)
        }
    }
}

// MARK:- WKNavigationDelegate delegate

extension ApphudScreenController : WKNavigationDelegate {
    
    func handleNavigationAction(navigationAction: WKNavigationAction) -> Bool {
        
        if webView.tag == 1, let lastComponent = navigationAction.request.url?.lastPathComponent {    
            switch lastComponent {
            case "confirm":
                self.purchaseTapped(url: navigationAction.request.url)
                return false
            case "dismiss":
                self.closeTapped()
                return false
            case "link":
                self.openURL(url: navigationAction.request.url)
                return false
            case "restore":
                self.restoreTapped()
                return false
            default:
                break
            }
        }
        
        return true
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView.tag == 1 {
            makeVisible()
        } else {
            getScreenInfo()
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
