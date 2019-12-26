//
//  ViewController.swift
// Apphud
//
//  Created by ren6 on 11/06/2019.
//  Copyright © 2019 Softeam Inc. All rights reserved.
//

import UIKit
import StoreKit

class ViewController: UITableViewController{
    
    var products = [SKProduct]()
    
    var introductoryEligibility = [String : Bool]()
    var promoOffersEligibility = [String : Bool]()
    var canShowApphudScreen = true
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // In this example we set delegate to ViewController to reload tableview when changes come
        Apphud.setDelegate(self)
        Apphud.setUIDelegate(self)
        
        reload()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Restore transactions", style: .done, target: self, action: #selector(restore))        
    }

    override func viewWillAppear(_ animated: Bool) {
        print("will appear")
        super.viewWillAppear(animated)
    }
    
    override func viewDidAppear(_ animated: Bool) {
        print("did appear")
        super.viewDidAppear(animated)
    }
    
    @objc func restore(){
        Apphud.restoreSubscriptions { subscriptions in self.reload()}
    }
    
    @objc func reload(){
        Apphud.checkEligibilitiesForIntroductoryOffers(products: products) { (response) in
            self.introductoryEligibility = response
            if #available(iOS 12.2, *) {
                Apphud.checkEligibilitiesForPromotionalOffers(products: self.products) { (response) in
                    self.promoOffersEligibility = response
                    self.tableView.reloadData()
                }
            } else {                    
                self.tableView.reloadData()
            }
        }            
        
        tableView.reloadData()
    }
    
    //MARK:- TableView Delegate methods
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return products.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        
        let cell = tableView.dequeueReusableCell(withIdentifier: "productCell", for: indexPath)
        let product = products[indexPath.item]                        
        
        var text = product.fullSubscriptionInfoString() ?? ""
        
        if self.promoOffersEligibility[product.productIdentifier] != nil {
            text = "\(text)\nEligible for promo: \(self.promoOffersEligibility[product.productIdentifier]!)"
        }
        if self.introductoryEligibility[product.productIdentifier] != nil {
            text = "\(text)\nEligible for introductory: \(self.introductoryEligibility[product.productIdentifier]!)"
        } 
        
        cell.textLabel?.text = text
        
        if let subscription = Apphud.subscriptions()?.first(where: {$0.productId == product.productIdentifier}) {
            
            cell.detailTextLabel?.text = subscription.expiresDate.description(with: Locale.current) + "\nState: \(subscription.status.toStringDuplicate())\nIntroductory used:\(subscription.isIntroductoryActivated)".uppercased()
        } else {
            cell.detailTextLabel?.text = "Not active"
        }
        
        return cell            
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let product = products[indexPath.item]

        if #available(iOS 12.2, *) {
            if product.discounts.count > 0 && (Apphud.subscriptions()?.first(where: {$0.productId == product.productIdentifier}) != nil){
                // purchase promo offer                
                showPromoOffersAlert(product: product)
            } else {
                purchaseProduct(product: product)
            }
        } else {
            purchaseProduct(product: product)
        }   
    }
    
    @available(iOS 12.2, *)
    func showPromoOffersAlert(product : SKProduct) {
        
        let controller = UIAlertController(title: "You already have subscription for this product", message: "would you like to activate promo offer?", preferredStyle: .alert)
        
        for discount in product.discounts {
            controller.addAction(UIAlertAction(title: "Purchase Promo: \(discount.identifier!)", style: .default, handler: { act in
                self.purchaseProduct(product: product, promoID: discount.identifier!)
            }))
        }
        
        controller.addAction(UIAlertAction(title: "Purchase Product As Usual", style: .destructive, handler: { act in
            self.purchaseProduct(product: product)
        }))
        
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(controller, animated: true, completion: nil)
    }
    
    @available(iOS 12.2, *)
    func purchaseProduct(product: SKProduct, promoID: String){
        Apphud.purchasePromo(product, discountID: promoID) { (subsription, error) in
            self.reload()
        } 
    }
    
    func purchaseProduct(product : SKProduct) {
        Apphud.purchase(product) { (subs, error) in
            self.reload()            
        }
    }
}

extension ViewController : ApphudDelegate {
    
    func apphudDidChangeUserID(_ userID: String) {
        print("new apphud user id: \(userID)")
    }
    
    func apphudDidFetchStoreKitProducts(_ products: [SKProduct]) {
        print("apphudDidFetchStoreKitProducts")
        self.products = products
        self.reload()
    }
    
    func apphudSubscriptionsUpdated(_ subscriptions: [ApphudSubscription]) {
        self.reload()
        print("apphudSubscriptionsUpdated")
    }
}

extension ViewController : ApphudUIDelegate {
    
    func apphudShouldShowScreen(controller: UIViewController) -> Bool {
        return canShowApphudScreen
    }
    
    func apphudScreenPresentationStyle(controller: UIViewController) -> UIModalPresentationStyle {
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .pageSheet
        } else {
            return .overFullScreen
        }
    }
    
    func apphudDidDismissScreen(controller: UIViewController) {
        print("did dismiss screen")
    }    
}
