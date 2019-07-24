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
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // In this example we set delegate to ViewController to reload tableview when changes come
        Apphud.setDelegate(self)
        
        NotificationCenter.default.addObserver(self, selector: #selector(reload), name: IAP_PRODUCTS_DID_LOAD_NOTIFICATION, object: nil)
        reload()
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Restore transactions", style: .done, target: self, action: #selector(restore))        
    }
    
    @objc func restore(){
        Apphud.restoreSubscriptions()
    }
    
    @objc func reload(){
        if let prs = IAPManager.shared.products {
            products = prs
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
        
        cell.textLabel?.text = product.fullSubscriptionInfoString()
        
        if let subscription = Apphud.purchasedSubscriptionFor(productID: product.productIdentifier) {
            cell.detailTextLabel?.text = subscription.expiresDate.description(with: Locale.current) + "\nState: \(subscription.status.toString())".uppercased()
        } else {
            cell.detailTextLabel?.text = "Not active"
        }
        
        return cell            
    }
    
    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        
        tableView.deselectRow(at: indexPath, animated: true)
        
        let product = products[indexPath.item]
        
        IAPManager.shared.purchaseProduct(product: product, success: { 
            
            Apphud.submitPurchase(product.productIdentifier, callback: { (subscription, error) in
                if let subscription = subscription {
                    // unlock premium functionality
                    print("subscription is active! \(subscription.expiresDate)")
                }
                self.reload()
            })
            
        }) { (error) in
            print("Error purchasing: \(error?.localizedDescription ?? "")")
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
    
    func fullSubscriptionInfoString() -> String?{
        
        guard subscriptionPeriod != nil else {return nil}
        
        var unit = ""
        switch subscriptionPeriod!.unit {
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
        
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = priceLocale
        
        let localizedPrice = numberFormatter.string(from: price)
        
        var string = localizedTitle + ": \(localizedPrice ?? "")" + ", \(subscriptionPeriod!.numberOfUnits) " + "\(unit)"
        
        if let intro = introductoryPrice {
            let intro_periods_count = intro.numberOfPeriods
            
            var intro_unit = ""
            switch intro.subscriptionPeriod.unit {
            case .day:
                intro_unit = "day"
            case .week:
                intro_unit = "week"
            case .month:
                intro_unit = "month"
            case .year:
                intro_unit = "year"
            default:
                break
            }
            
            let intro_unit_count = intro.subscriptionPeriod.numberOfUnits
            
            let introPrice = numberFormatter.string(from: intro.price)
            
            if intro.paymentMode == .payAsYouGo {
                string = "\(string) INTRO PAY AS YOU GO: \(introPrice ?? "") every \(intro_unit_count) \(intro_unit) and pay it \(intro_periods_count) times"
            } else if intro.paymentMode == .payUpFront {
                string = "\(string) INTRO PAY UP FRONT: \(introPrice ?? "") per \(intro_unit_count) \(intro_unit) for  \(intro_periods_count) times"   
            } else if intro.paymentMode == .freeTrial {
                string = "\(string) FREE TRIAL: \(introPrice ?? "") per \(intro_unit_count) \(intro_unit) for  \(intro_periods_count) times"  
            }
        }
        return string
    }
}
