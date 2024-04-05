//
//  LaunchViewController.swift
//  sampleapp
//
//  Created by Apphud on 13.02.2024.
//  Copyright © 2024 Apphud. All rights reserved.
//

import UIKit

class LaunchViewController: UIViewController {
    
    let paramsService = ParamsService()
    
    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        guard self.paramsService.showedTutorial else {
            self.performSegue(withIdentifier: "showOnboarding", sender: nil)
            return
        }
        
        self.performSegue(withIdentifier: "showTabbar", sender: nil)
    }
}
