//
//  ApphudScreenController.swift
//  apphud
//
//  Created by Renat on 26/08/2019.
//  Copyright © 2019 softeam. All rights reserved.
//

import UIKit
import WebKit

class ApphudScreenController: UIViewController, WKNavigationDelegate {

    private lazy var webView : WKWebView = { 
        let config = WKWebViewConfiguration()
        let wv = WKWebView(frame: self.view.bounds, configuration: config)
        wv.navigationDelegate = self
        self.view.addSubview(wv)
        
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: self.view.topAnchor),
            wv.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: self.view.bottomAnchor),
        ])
        
        return wv
    }()
    
    var rule: String!
    var screen: ApphudScreen?
    var screenID: String!
    
    class func show(ruleID: String, screenID: String){
        let controller = ApphudScreenController()
        controller.rule = ruleID
        controller.screenID = screenID
        controller.loadScreenDetails()
        controller.loadScreenPage()
        apphudVisibleViewController()?.present(controller, animated: true, completion: nil)
    }
    
    private func loadScreenDetails(){
        ApphudInternal.shared.getScreenDetails(screenID: self.screenID) { screen in
            self.screen = screen
            self.reloadUI()
        }
    }
    
    private func loadScreenPage(){
        if let request = ApphudHttpClient.shared.makeScreenRequest(screenID: self.screenID) {
            self.webView.load(request)
        } 
    }
    
    private func reloadUI(){
        // inject product and offer prices
    }
    
    override func viewDidLoad() {
        super.viewDidLoad()
    }
}
