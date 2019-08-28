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
    
    var ruleID: String!
    var screen: ApphudScreen?
    var screenID: String!
    var addedObserver = false
    var isPurchasing = false
    var start = Date()
    
    deinit {
        NotificationCenter.default.removeObserver(self)
    }
    
    class func show(ruleID: String, screenID: String){
        let controller = ApphudScreenController()
        controller.ruleID = ruleID
        controller.screenID = screenID
        controller.loadScreenPage()
        apphudVisibleViewController()?.present(controller, animated: true, completion: nil)
        
    }
   
    private func loadScreenPage(){
        if let request = ApphudHttpClient.shared.makeScreenRequest(screenID: self.screenID) {
            print("start html page: \(request.url)")
            self.webView.alpha = 0
            self.webView.load(request)
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
                    // handle error
                }
            }
        }
    }

    @objc private func reloadUI(){
        
        print("ApphudScreenController reload UI")
        
        guard let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == self.screen!.product_id}) else {
            if !addedObserver {
                NotificationCenter.default.addObserver(self, selector: #selector(reloadUI), name: ApphudStoreKitProductsFetched, object: nil)
                addedObserver = true
            }
            return
        }
        
        self.product = product
        discount = self.product!.discounts.first(where: {$0.identifier == self.screen!.promo_offer_id})
                
        webView.evaluateJavaScript("document.body.innerHTML") { (result, error) in
            
            if var html = result as? NSString {
                
                let firstDiv = html.range(of: "<div")
                var searchStart = 0
                if firstDiv.location != NSNotFound {                        
                    searchStart = firstDiv.location
                }
                
                if self.discount != nil {            
                    let offerDuration = self.product!.discountDurationString(discount: self.discount!)
                    let offerUnit = self.product!.discountUnitString(discount: self.discount!)
                    let offerPrice = self.product!.localizedDiscountPrice(discount: self.discount!)
                    let discountPercents = 100 * (self.product!.price.floatValue - self.discount!.price.floatValue) / self.product!.price.floatValue
                                        
                    html = html.replacingOccurrences(of: "{offer_duration}", with: offerDuration, options: [], range: NSMakeRange(searchStart, html.length - searchStart)) as NSString
                    html = html.replacingOccurrences(of: "{offer_unit}", with: offerUnit, options: [], range: NSMakeRange(searchStart, html.length - searchStart)) as NSString
                    html = html.replacingOccurrences(of: "{offer_price}", with: offerPrice, options: [], range: NSMakeRange(searchStart, html.length - searchStart)) as NSString
                }
                
                let regularUnit = self.product!.regularUnitString()
                let regularPrice = self.product!.localizedPrice()
                
                html = html.replacingOccurrences(of: "{regular_unit}", with: regularUnit, options: [], range: NSMakeRange(searchStart, html.length - searchStart)) as NSString
                html = html.replacingOccurrences(of: "{regular_price}", with: regularPrice, options: [], range: NSMakeRange(searchStart, html.length - searchStart)) as NSString
                
                self.webView.tag = 1
                self.webView.loadHTMLString(html as String, baseURL: nil)
            }
            
            
            
            
        }
        
        
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
        ApphudInternal.shared.trackMobileEvent(name: "purchase_screen_presented", ruleID: self.ruleID, callback: {})
    }
    
    //MARK:- Actions
    
    private func purchaseTapped(){

        guard let discountID = self.discount?.identifier else {
            return
        }
        
        if isPurchasing {return}
        isPurchasing = true
        
        ApphudInternal.shared.trackMobileEvent(name: "purchase_screen_purchase_tapped", ruleID: self.ruleID, callback: {})
        
        Apphud.signPromoOffer(productID: self.product!.productIdentifier, discountID: discountID) { (paymentDiscount, error) in
            if let signed = paymentDiscount {
                Apphud.makePurchase(product: self.product!, discount: signed, callback: { (subscription, error) in
                    self.isPurchasing = false                    
                    if subscription != nil{
                        self.dismiss()
                    }
                })
            } else {
                self.isPurchasing = false
            }
        }            
        
    }
    
    private func closeTapped(){
        ApphudInternal.shared.trackMobileEvent(name: "purchase_screen_user_dismissed", ruleID: self.ruleID, callback: {})
        dismiss()
    }
    
    private func dismiss(){
        dismiss(animated: true, completion: nil)
    }
}

@available(iOS 12.2, *)
extension ApphudScreenController : WKScriptMessageHandler {
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        print("message: \(message)")
    }
}

@available(iOS 12.2, *)
extension ApphudScreenController : WKNavigationDelegate {
    
    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        if webView.tag == 1 {
            webView.alpha = 1
            
            let date = Date().timeIntervalSince(start)
            
            print("exec time: \(date)")
        } else {
            getScreenInfo()
        }
    }
    
    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        print("didFailh navigation")
    }
    
    func webView(_ webView: WKWebView, didReceiveServerRedirectForProvisionalNavigation navigation: WKNavigation!) {
        print("didReceiveServerRedirectForProvisionalNavigation")
    }
    
    func webView(_ webView: WKWebView, decidePolicyFor navigationResponse: WKNavigationResponse, decisionHandler: @escaping (WKNavigationResponsePolicy) -> Void) {
        print("decidePolicyFor navigationResponse")
        decisionHandler(.allow)
    }
}
