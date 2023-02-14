//
//  ContentViewController.swift
//  ApphudSDKDemo
//
//  Created by Valery on 15.06.2021.
//  Copyright © 2021 softeam. All rights reserved.
//

import UIKit
import ApphudSDK

class ContentViewController: UIViewController {

    @IBOutlet weak var statusLabel: UILabel!

    override func viewDidLoad() {
        super.viewDidLoad()

        title = "Apphud Content"

        reloadUI()

        NotificationCenter.default.addObserver(self, selector: #selector(reloadUI), name: Apphud.didUpdateSubscriptionsNotification(), object: nil)
    }

    @objc func reloadUI() {
        self.statusLabel.text = AppVariables.isPremium ? "Premium is ON" : "No Premium Access"
    }

    @IBAction func showPaywallPressed(_ sender: Any) {
        Router.shared.showRepeatPaywall(.main) { result in
            print("Purchase Result: \(result)")
        } completion: { [weak self] in
            self?.reloadUI()
        }
    }

    @IBAction func redeemTapped() {
        if #available(iOS 14.0, *) {
            Apphud.presentOfferCodeRedemptionSheet()
        } else {
            // Fallback on earlier versions
        }
    }
}
