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
@available(iOS 12.2, *)
class ApphudScreenController: UIViewController{

    #warning("check ipad and other iphone sizes")
    
    private var product: SKProduct?
    private var discount: SKProductDiscount?
    private var signedDiscount: SKPaymentDiscount?
    
    private lazy var webView : WKWebView = { 
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: self.view.bounds, configuration: config)
        wv.navigationDelegate = self
        self.view.addSubview(wv)
        wv.allowsLinkPreview = false
        wv.allowsBackForwardNavigationGestures = false
        
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: self.view.topAnchor),
            wv.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
        
        return wv
    }()
    
    var rule: ApphudRule
    var option: ApphudRuleOption
    
    var screen: ApphudScreen?
    var addedObserver = false
    var isPurchasing = false
    var start = Date()
    
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
        self.perform(#selector(failed), with: nil, afterDelay: 10.0)
        self.loadScreenPage()
    }
    
    @objc private func failed(){
        // for now just dismiss
        self.dismiss()
    }
    
    private func loadScreenPage(){
        if let screenID = self.option.screenID, let request = ApphudHttpClient.shared.makeScreenRequest(screenID: screenID) {   
            apphudLog("started loading page:\(request)")
            self.webView.alpha = 0
            self.webView.load(request)
        } else {
            failed()
        }
    }
    
    private func getScreenInfo(){
        
        let js = "window.screenInfo"
        self.webView.evaluateJavaScript(js) { (result, error) in
            DispatchQueue.main.async {
                if let dict = result as? [String : Any] {
                    let screen = ApphudScreen(dictionary: dict)
                    self.screen = screen
                    self.reloadUI()
                } else {
                    self.failed()
                }
            }
        }
    }

    @objc private func reloadUI(){
        
        guard let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == self.screen!.product_id}) else {
            if !addedObserver {
                NotificationCenter.default.addObserver(self, selector: #selector(reloadUI), name: ApphudStoreKitProductsFetched, object: nil)
                addedObserver = true
            }
            return
        }
        self.product = product
        discount = self.product!.discounts.first(where: {$0.identifier == self.screen!.offer_id})
        webView.evaluateJavaScript("document.documentElement.outerHTML") { (result, error) in
            if var html = result as? NSString {
                html = self.replaceMacroses(html: html)
                self.webView.tag = 1                
                
                let url = URL(string: ApphudHttpClient.shared.domain_url_string)
                
                self.webView.loadHTMLString(html as String, baseURL: url)
            } else {
                self.failed()
            }
        }
    }
     
    func replaceMacroses(html: NSString) -> NSString{
        let firstDiv = html.range(of: "<div")
        var searchStart = 0
        if firstDiv.location != NSNotFound {                        
            searchStart = firstDiv.location
        }
        var newHtml = html
        if self.discount != nil {            
            let offerDuration = self.product!.discountDurationString(discount: self.discount!)
            let offerUnit = self.product!.discountUnitString(discount: self.discount!)
            let offerPrice = self.product!.localizedDiscountPrice(discount: self.discount!)
//            let discountPercents = 100 * (self.product!.price.floatValue - self.discount!.price.floatValue) / self.product!.price.floatValue
            
            newHtml = newHtml.replacingOccurrences(of: "{offer_duration}", with: offerDuration, options: [], range: NSMakeRange(searchStart, newHtml.length - searchStart)) as NSString
            newHtml = newHtml.replacingOccurrences(of: "{offer_unit}", with: offerUnit, options: [], range: NSMakeRange(searchStart, newHtml.length - searchStart)) as NSString
            newHtml = newHtml.replacingOccurrences(of: "{offer_price}", with: offerPrice, options: [], range: NSMakeRange(searchStart, newHtml.length - searchStart)) as NSString
        }
        
        let regularUnit = self.product!.regularUnitString()
        let regularPrice = self.product!.localizedPrice()
        
        newHtml = newHtml.replacingOccurrences(of: "{regular_unit}", with: regularUnit, options: [], range: NSMakeRange(searchStart, newHtml.length - searchStart)) as NSString
        newHtml = newHtml.replacingOccurrences(of: "{regular_price}", with: regularPrice, options: [], range: NSMakeRange(searchStart, newHtml.length - searchStart)) as NSString
        
        return newHtml
    }
    
    func present(){
        let date = Date().timeIntervalSince(start)
        apphudLog("exec time: \(date)")
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(failed), object: nil)
        webView.alpha = 1
    }
    
    //MARK:- Actions
    
    private func purchaseTapped(){

        guard let discountID = self.discount?.identifier else {
            return
        }
        
        if isPurchasing {return}
        isPurchasing = true
        
        Apphud.signPromoOffer(productID: self.product!.productIdentifier, discountID: discountID) { (paymentDiscount, error) in
            if let signed = paymentDiscount {
                Apphud.makePurchase(product: self.product!, discount: signed, callback: { (subscription, error) in
                    
                    self.isPurchasing = false                    
                    if subscription != nil{
                        // successful purchase                        
                        ApphudInternal.shared.trackRuleEvent(ruleID: self.rule.id, params: ["kind" : "offer_activated", "option_id" : self.option.id, "offer_id" : discountID, "screen_id" : self.option.screenID!]) {}

                        self.dismiss()
                    }
                })
            } else {
                self.isPurchasing = false
            }
        }            
        
    }
    
    private func closeTapped(){
        dismiss()
    }
    
    private func dismiss(){
        dismiss(animated: true, completion: nil)
    }
    
    private func openURL(privacyOrTerms: Bool){
        var urlString: String?
        if privacyOrTerms {
            urlString = self.screen?.privacy_url
        } else {
            urlString = self.screen?.terms_url
        }
        if urlString != nil, let url = URL(string: urlString!), UIApplication.shared.canOpenURL(url){
            let controller = SFSafariViewController(url: url)
            present(controller, animated: true, completion: nil)
        }
    }
}

@available(iOS 12.2, *)
extension ApphudScreenController : WKNavigationDelegate {
    
    func handleNavigationAction(navigationAction: WKNavigationAction) -> Bool {
        
        if webView.tag == 1, let lastComponent = navigationAction.request.url?.lastPathComponent {    
            switch lastComponent {
            case "confirm":
                self.purchaseTapped()
                return false
            case "dismiss":
                self.closeTapped()
                return false
            case "terms":
                self.openURL(privacyOrTerms: false)
                return false
            case "privacy":
                self.openURL(privacyOrTerms: true)
                return false
            default:
                break
            }
        }
        
        return true
    }
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView.tag == 1 {
            present()
        } else {
            getScreenInfo()
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
