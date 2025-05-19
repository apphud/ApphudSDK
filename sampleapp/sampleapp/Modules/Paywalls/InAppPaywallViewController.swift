//
//  InAppPaywallViewController.swift
//  sampleapp
//
//  Created by Apphud on 13.02.2024.
//  Copyright © 2024 Apphud. All rights reserved.
//

import UIKit
import ApphudSDK

class InAppPaywallViewController: PaywallParentController {
           
    override func viewDidLoad() {
        self.placementIdentifier = "inapp_placement"
        super.viewDidLoad()
    }
    
    // MARK: - Actions
    
    override func purchaseProduct(_ product: ApphudProduct) async {
        self.showLoader()
        
        let result = await Apphud.purchase(product)
        self.purchaseCallback?(result.error == nil)
        self.hideLoader()
        
        if result.error == nil {
            self.closeAction()
        }
    }
    
    private func closeAction() {
        self.dismiss(animated: true)
    }
}
