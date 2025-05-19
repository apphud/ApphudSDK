//
//  OnboardingPaywallViewController.swift
//  sampleapp
//
//  Created by Apphud on 13.02.2024.
//  Copyright © 2024 Apphud. All rights reserved.
//

import UIKit
import ApphudSDK

class OnboardingPaywallViewController: PaywallParentController {
    
    override func viewDidLoad() {
        self.placementIdentifier = "onboarding_placement"
        super.viewDidLoad()
    }
    
    // MARK: - Actions
    
    override func purchaseProduct(_ product: ApphudProduct) async {
        self.showLoader()
        
        let result = await Apphud.purchase(product)
        self.hideLoader()
        
        if result.error == nil {
            self.showTabbar()
        }
    }
    
    @IBAction func skipAction(_ sender: Any) {
        self.showTabbar()
    }
    
    private func showTabbar() {
        router.showTabbar()
    }
}
