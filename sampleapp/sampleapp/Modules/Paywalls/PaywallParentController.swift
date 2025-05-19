//
//  PaywallParentController.swift
//  sampleapp
//
//  Created by Renat Kurbanov on 19.05.2025.
//

import ApphudSDK
import UIKit

class PaywallParentController: UIViewController {
        
    @IBOutlet weak var productsStackView: UIStackView!
    @IBOutlet weak var backView: UIView!
    
    private var products:[ApphudProduct] = []
    private var paywall: ApphudPaywall?
    
    var purchaseCallback: ((Bool) -> Void)?
    
    let router = Router.shared
    let paramsService = ParamsService()
    
    var selectedProduct: ApphudProduct?
    
    var placementIdentifier: String = "invalid"
    
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
    
    private func getPaywalls() async {
        // get placement with identifier for this location
        let placement = await Apphud.placement(placementIdentifier)
        
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
    
    @IBAction func continueAction(_ sender: Any) {
        guard let product = selectedProduct else {return}
        
        Task { @MainActor in
            await self.purchaseProduct(product)
        }
    }
    
    func purchaseProduct(_ product: ApphudProduct) async {
        // to be overrided
    }
    
    private func updateUIWith(json:[String: Any]?) {
        if let backColor = json?["color"] as? String {
            backView.backgroundColor = UIColor(hex:backColor)
        }
    }
    
    @objc func productSelected(gesture: UITapGestureRecognizer) {
        if let view = gesture.view as? PaywallProductView {
            selectedProduct = view.product
            self.updateUI()
        }
    }
}
