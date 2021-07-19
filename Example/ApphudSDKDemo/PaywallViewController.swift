//
//  PaywallViewController.swift
//  ApphudSDKDemo
//
//  Created by Валерий Левшин on 15.06.2021.
//  Copyright © 2021 softeam. All rights reserved.
//

import UIKit
import ApphudSDK

class PaywallViewController: UIViewController {
    
    let currentPaywallIdentifier = "billing_paywal"
    var products:[ApphudProduct]?
    var paywall:ApphudPaywall?
    var dismissCompletion: (()->())?
    
    @IBOutlet weak var paywallCollectionView: UICollectionView!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        if Apphud.paywalls != nil {
            handlePaywallsReady(paywalls: Apphud.paywalls!)
        } else {
            Apphud.paywallsDidLoadCallback { [weak self] pwls in
                self?.handlePaywallsReady(paywalls: pwls)
            }
        }
    }
    
    private func handlePaywallsReady(paywalls: [ApphudPaywall]) {
        // retrieve current paywall with identifier
        self.paywall = paywalls.first(where: { $0.identifier == self.currentPaywallIdentifier })
        
        // retrieve the products [ApphudProduct] from current paywall
        self.products = self.paywall?.products
        
        // send Apphud log, that your paywall shown
        Apphud.paywallShown(self.paywall)
        
        // setup your UI
        self.setupViewConfiguration()
    }
    
    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        
        // send Apphud log, that your paywall closed
        Apphud.paywallClosed(self.paywall)
        dismissCompletion?()
    }
    
    func setupViewConfiguration() {
        self.paywallCollectionView.reloadData()
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout
extension PaywallViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {
    
    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return products?.count ?? 0
    }
    
    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PaywallCollectionViewCellid", for: indexPath) as! PaywallCollectionViewCell
       
        let product = products?[indexPath.item]
        cell.purchaseTypeLabel.text = product?.skProduct?.getProductDuration()
        cell.purchasePriceLabel.text = product?.skProduct?.getProductPrice()
        cell.purchaseDescriptionLabel.text = product?.skProduct?.localizedTitle
                
        return cell
    }
    
    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let product = products?[indexPath.item] {
            self.showLoader()
            Apphud.purchase(product) { (result) in
                self.hideLoader()
                if result.error == nil {
                    self.dismiss(animated: true, completion: nil)
                }
            }
        }
    }
    
    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: UIScreen.main.bounds.size.width/2 - 10, height: UIScreen.main.bounds.size.width/2 - 10)
    }
}
