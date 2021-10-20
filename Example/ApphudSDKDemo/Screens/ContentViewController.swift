//
//  ContentViewController.swift
//  ApphudSDKDemo
//
//  Created by Валерий Левшин on 15.06.2021.
//  Copyright © 2021 softeam. All rights reserved.
//

import UIKit
import ApphudSDK

class ContentViewController: UIViewController {

    @IBOutlet weak var statusLabel: UILabel!
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.reloadUiIfNedeed()
    }
    
    func reloadUiIfNedeed() {
        self.statusLabel.text = isPremium ? "PRO status is ON" : "Default status"
    }
    
    var isPremium: Bool {
        Apphud.hasActiveSubscription() ||
        Apphud.isNonRenewingPurchaseActive(productIdentifier: "com.apphud.lifetime")
    }
    
    @IBAction func showPaywallPressed(_ sender: Any) {
        Router.shared.showRepeatPaywall {
            self.reloadUiIfNedeed()
        }
    }
}
