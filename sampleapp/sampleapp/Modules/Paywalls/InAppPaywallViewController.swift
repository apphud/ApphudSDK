//
//  InAppPaywallViewController.swift
//  sampleapp
//
//  Created by Apphud on 13.02.2024.
//  Copyright © 2024 Apphud. All rights reserved.
//

import UIKit
import ApphudSDK

class InAppPaywallViewController: UIViewController {
    
    @IBOutlet weak var productsStackView: UIStackView!
    @IBOutlet weak var backView: UIView!
    
    private var products:[ApphudProduct] = []
    private var paywall: ApphudPaywall?
    
    var purchaseCallback: ((Bool) -> Void)?
    
    let router = Router.shared
    let paramsService = ParamsService()
    
    private var selectedProduct: ApphudProduct?
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        Task { @MainActor in
            await getPaywalls()
        }
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        // send Apphud log, that your paywall closed
        if let paywall = paywall {
            Apphud.paywallClosed(paywall)
        }
    }
    
    // MARK: - ViewModel Methods
    private func getPaywalls() async {
        // get placement with identifier for this location
        let placement = await Apphud.placement("inapp_placement")
        
        // get paywall form placement
        if let paywall = placement?.paywall {
            self.handlePaywallReady(paywall: paywall)
        }
    }
    
    private func handlePaywallReady(paywall: ApphudPaywall) {
        self.paywall = paywall
        
        // retrieve the products [ApphudProduct] from current paywall
        self.products = paywall.products
        
        // send Apphud log, that your paywall shown
        Apphud.paywallShown(paywall)
        
        // setup your UI
        self.updateUI()
        
        // setup your UI with custom Json
        self.updateUIWith(json:paywall.json)
    }
    
    // MARK: - UI
    func updateUI() {
        if productsStackView.arrangedSubviews.count == 0 {
            products.forEach { product in
                let productView = PaywallProductView.viewWith(product: product)
                productsStackView.addArrangedSubview(productView)
                productView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(productSelected)))
            }
        }
        
        productsStackView.arrangedSubviews.forEach { v in
            if let productView = v as? PaywallProductView {
                productView.isSelected = selectedProduct == productView.product
            }
        }
    }
    
    private func updateUIWith(json:[String: Any]?) {
        if let backColor = json?["color"] as? String {
            backView.backgroundColor = UIColor(hex:backColor)
        }
    }
    
    // MARK: - Actions
    @objc func productSelected(gesture: UITapGestureRecognizer) {
        if let view = gesture.view as? PaywallProductView {
            selectedProduct = view.product
            updateUI()
        }
    }
    
    func purchaseProduct(_ product: ApphudProduct) async {
        self.showLoader()
        
        let result = await Apphud.purchase(product)
        self.purchaseCallback?(result.error == nil)
        self.hideLoader()
        
        if result.error == nil {
            self.closeAction()
        }
    }
    
    @IBAction func continueAction(_ sender: Any) {
        guard let product = selectedProduct else {return}
        
        Task { @MainActor in
            await self.purchaseProduct(product)
        }
    }
    
    private func closeAction() {
        self.dismiss(animated: true)
    }
}