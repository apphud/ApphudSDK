//
//  ViewController.swift
// Apphud
//
//  Created by ren6 on 11/06/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import UIKit
import StoreKit
import ApphudSDK

typealias Callback = (() -> Void)

class ViewController: UITableViewController{
    var paywalls = [ApphudPaywall]()
    var rowsActions = [(String, Callback)]()
        
    override func viewDidLoad() {
        super.viewDidLoad()

        Apphud.setDelegate(self)
        Apphud.setUIDelegate(self)

        setupRowActions()
        
        if Apphud.paywalls != nil {
            paywalls = Apphud.paywalls!
            reloadUI()
        } else {
            Apphud.paywallsDidLoadCallback { [weak self] pwls in
                self?.paywalls = pwls
                self?.reloadUI()
            }
        }
        
        reload()
    }
    
    func setupRowActions() {
        rowsActions = [
            ("Restore", { self.restore() }),
            ("Offer Code Redemption Sheet", { self.presentOfferCodeSheet() }),
            ("Fetch Raw Receipt", { self.fetchRawReceipt() }),
            ("Log out <\(Apphud.userID())>", { Apphud.logout() })
        ]
    }
    
    @objc func presentOfferCodeSheet() {
        if #available(iOS 14.0, *) {
            Apphud.presentOfferCodeRedemptionSheet()
        } else {
            print("Not supported")
        }
    }
    
    @objc func reloadUI(){
        reload()
    }
            
    @objc func fetchRawReceipt() {
        Apphud.fetchRawReceiptInfo { receipt in
            if let receipt = receipt {
                print("details = \(receipt.originalApplicationVersion), creation_date = \(String(describing: receipt.receiptCreationDate))")
            } else {
                print("could not fetch raw receipt")
            }
        }
    }
    
    @objc func restore(){
        Apphud.restorePurchases { _, _, _ in
            self.reload()
        }
    }
    
    @objc func reload(){
        tableView.reloadData()
    }
    
    //MARK:- TableView Delegate methods
    
    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        section == 0 ? "ACTIONS" : "PRODUCTS"
    }
    
    override func numberOfSections(in tableView: UITableView) -> Int {
        1 + paywalls.count
    }
    
    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        section == 0 ? rowsActions.count : paywalls[section - 1].products.count
    }
    
    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "productCell", for: indexPath)
        
        if indexPath.section == 0 {
            cell.textLabel?.text = rowsActions[indexPath.row].0
            cell.detailTextLabel?.text = nil
        } else {
            let paywall = paywalls[indexPath.section - 1]
            let product = paywall.products[indexPath.item]
            
            let text = product.skProduct?.getFullSubscriptionInfoString() ?? "PRODUCT UNAVAILABLE: \(product.productId)"
            cell.textLabel?.text = text
            if let subscription = Apphud.subscriptions()?.first(where: {$0.productId == product.productId}) {
                cell.detailTextLabel?.text = subscription.expiresDate.description(with: Locale.current) + "\nState: \(subscription.status.toStringDuplicate())\nIntroductory used:\(subscription.isIntroductoryActivated)".uppercased()
            } else {
                cell.detailTextLabel?.text = "Not active"
            }
        }
    
        return cell
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        if indexPath.section == 0 {
            rowsActions[indexPath.row].1()
            return
        }
        
        let paywall = paywalls[indexPath.section - 1]
        let product = paywall.products[indexPath.item]

        if #available(iOS 12.2, *) {
            if product.skProduct?.discounts.count ?? 0 > 0 {
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
    func showPromoOffersAlert(product : ApphudProduct) {
        
        let controller = UIAlertController(title: "You already have subscription for this product", message: "would you like to activate promo offer?", preferredStyle: .alert)
        
        for discount in product.skProduct?.discounts ?? [] {
            controller.addAction(UIAlertAction(title: "Purchase Promo: \(discount.identifier!)", style: .default, handler: { act in
                self.purchasePromo(product: product, promoID: discount.identifier!)
            }))
        }
        
        controller.addAction(UIAlertAction(title: "Purchase Product As Usual", style: .destructive, handler: { act in
            self.purchaseProduct(product: product)
        }))
        
        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(controller, animated: true, completion: nil)
    }
    
    @available(iOS 12.2, *)
    func purchasePromo(product: ApphudProduct, promoID: String) {
        
        guard let skproduct = product.skProduct else {return}
        
        Apphud.purchasePromo(skproduct, discountID: promoID, { result in
            self.reload()
        })
    }
    
    func purchaseProduct(product : ApphudProduct) {
        Apphud.purchase(product) { result in
            if result.error != nil {
                self.notifyPurchaseError(error: result.error!)
            }
            self.reload()
        }
    }
        
    func notifyPurchaseError(error: Error) {
        let controller = UIAlertController(title: "Error", message: error.localizedDescription, preferredStyle: .alert)
        controller.addAction(UIAlertAction(title: "Ok", style: .default, handler: nil))
        present(controller, animated: true, completion: nil)
    }
}

extension ViewController : ApphudDelegate {
    
    func apphudDidFetchStoreKitProducts(_ products: [SKProduct]) {
        self.reload()
    }
    
    func apphudSubscriptionsUpdated(_ subscriptions: [ApphudSubscription]) {
        self.reload()
    }
}

extension ViewController : ApphudUIDelegate {
    
    func apphudScreenPresentationStyle(controller: UIViewController) -> UIModalPresentationStyle {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .pageSheet
        } else {
            return .overFullScreen
        }
    }
}
