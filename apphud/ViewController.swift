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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // In this example we set delegate to ViewController to reload tableview when changes come
        Apphud.setDelegate(self)
        
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: IAP_PRODUCTS_DID_LOAD_NOTIFICATION, object: nil)
        reload()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Restore transactions", style: .done, target: self, action: #selector(restore))        
    }
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
    }
    
    @objc func restore(){
        SKPaymentQueue.default().restoreCompletedTransactions()
        // OR Apphud.restoreSubscriptions()
    }
    
    @objc func reload(){
        if let prs = IAPManager.shared.products {
            products = prs
            print("new eligibility checks")
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
        
        if let subscription = Apphud.purchasedSubscriptionFor(productID: product.productIdentifier) {
            
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
            if product.discounts.count > 0 && (Apphud.purchasedSubscriptionFor(productID: product.productIdentifier) != nil){
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
        Apphud.signPromoOffer(productID: product.productIdentifier, discountID: promoID) { (paymentDiscount, error) in
            if let discount = paymentDiscount {
                Apphud.makePurchase(product: product, discount: discount, callback: { (subs, error) in
                    self.reload()
                })                
            } else {
                print("error signing \(String(describing: error))")
            }
        }
    }
    
    func purchaseProduct(product : SKProduct) {
        Apphud.makePurchase(product: product) { (subs, error) in
            self.reload()
        }
    }
    
}


extension ViewController : ApphudDelegate {
    func apphudSubscriptionsUpdated(_ subscriptions: [ApphudSubscription]) {
        self.reload()
    }
    
    func apphudDidChangeUserID(_ userID: String) {
        print("new apphud user id: \(userID)")
    }
}

extension SKProduct {
    
    func unitStringFrom(un : SKProduct.PeriodUnit) -> String{
        var unit = ""
        switch un {
        case .day:
            unit = "day"
        case .week:
            unit = "week"
        case .month:
            unit = "month"
        case .year:
            unit = "year"
        default:
            break
        }
        return unit
    }
    
    func localizedPriceFrom(price : NSDecimalNumber) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = priceLocale
        let priceString = numberFormatter.string(from: price)
        return priceString ?? ""
    }
    
    func discountDescription(discount : SKProductDiscount) -> String {
        
        
        let periods_count = discount.numberOfPeriods
        
        let unit = unitStringFrom(un: discount.subscriptionPeriod.unit)
        
        let unit_count = discount.subscriptionPeriod.numberOfUnits
        
        let priceString = localizedPriceFrom(price: discount.price)
        
        var string = ""
        if discount.paymentMode == .payAsYouGo {
            string = "PAY AS YOU GO: \(priceString) every \(unit_count) \(unit) and pay it \(periods_count) times"
        } else if discount.paymentMode == .payUpFront {
            string = "INTRO PAY UP FRONT: \(priceString) per \(unit_count) \(unit) for  \(periods_count) times"   
        } else if discount.paymentMode == .freeTrial {
            string = "FREE TRIAL: \(priceString) per \(unit_count) \(unit) for  \(periods_count) times"  
        }
        return string
    }
    
    func fullSubscriptionInfoString() -> String?{
        
        guard subscriptionPeriod != nil else {return nil}
        
        let unit = unitStringFrom(un: subscriptionPeriod!.unit)
        
        let priceString = localizedPriceFrom(price: price)
        
        var string = localizedTitle + ": \(priceString)" + ", \(subscriptionPeriod!.numberOfUnits) " + "\(unit)"
        
        if let intro = introductoryPrice {
            string = "\(string)\n\nHas following introductory offer:\n\(discountDescription(discount: intro))"
        }
        
        if #available(iOS 12.2, *) {
            if discounts.count > 0 {
                string = "\(string)\n\nHas following promotional offers:\n"
                for (i, discount) in discounts.enumerated() {
                    string = "\(string)PROMO OFFER #\(i+1): \(discountDescription(discount: discount))\n"                    
                }
            }
        }
        
        return string
    }
}

extension ApphudSubscriptionStatus {
    /**
     This function can only be used in Swift
     */
    func toStringDuplicate() -> String {
        
        switch self {
        case .trial:
            return "trial"
        case .intro:
            return "intro"
        case .promo:
            return "promo"
        case .grace:
            return "grace"
        case .regular:
            return "regular"
        case .refunded:
            return "refunded"
        case .expired:
            return "expired"
        default:
            return ""
        }
    }
}

