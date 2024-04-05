//
//  OnboardingFirstViewController.swift
//  sampleapp
//
//  Created by Apphud on 13.02.2024.
//  Copyright © 2024 Apphud. All rights reserved.
//

import UIKit
import ApphudSDK

class OnboardingViewController: UIViewController {
    
    let router = Router.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        // Do any additional setup after loading the view.
    }
    
    func showPaywall() {
        router.showOnboardingPaywall()
    }
    
    func showTabbar() {
        router.showTabbar()
    }
    
    @IBAction func finishOnboardingAction(_ sender: Any) {
        guard Apphud.hasPremiumAccess() else {
            self.showPaywall()
            return
        }
        
        self.showTabbar()
    }
}
