//
//  SettingsTableViewController.swift
//  sampleapp
//
//  Created by Apphud on 13.02.2024.
//  Copyright © 2024 Apphud. All rights reserved.
//

import UIKit
import ApphudSDK

enum MenuCellType {
    case appversion(String,String)
    case sdkversion(String,String)
    case restore(String,String)
    case status(String,String)
}

class SettingsTableViewController: UIViewController {
    
    @IBOutlet weak var tableView: UITableView!
    
    var menuItems: [MenuCellType] = []
    let router = Router.shared
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.setupMenu()
    }
    
    private func setupMenu() {
        menuItems.removeAll()
        
        menuItems.append(.appversion("App Version", "1.0"))
        menuItems.append(.sdkversion("SDK Version", "3.2.8"))
        menuItems.append(.restore("Restore Purchases", ""))
        menuItems.append(.status("Premium Status", Apphud.hasPremiumAccess() ? "Pro" : "No Pro"))
    }
    
    private func reloadUI() {
        setupMenu()
        tableView.reloadData()
    }
    
    private func restoreAction() {
        Task { @MainActor in
            showLoader()
            await Apphud.restorePurchases()
            hideLoader()
            
            reloadUI()
        }
    }
}

extension SettingsTableViewController: UITableViewDelegate, UITableViewDataSource {
    // MARK: - Table view data source
    
    func numberOfSections(in tableView: UITableView) -> Int {
        // #warning Incomplete implementation, return the number of sections
        return 1
    }
    
    func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        // #warning Incomplete implementation, return the number of rows
        return menuItems.count
    }
    
    func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        guard let cell = tableView.dequeueReusableCell(withIdentifier: "SettingsTableViewCellid", for: indexPath) as? SettingsTableViewCell else {
            return UITableViewCell()
        }
        
        let menuCellType = self.menuItems[indexPath.row]
        cell.fillCell(type: menuCellType)
        
        return cell
    }
    
    func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let menuCellType = self.menuItems[indexPath.row]
        
        switch menuCellType {
        case .appversion(_,_):
            return
        case .sdkversion(_,_):
            return
        case .restore(_,_):
            restoreAction()
        case .status(_,_):
            guard Apphud.hasPremiumAccess() else {
                router.showInAppPaywall { [self] purchased in
                    if purchased {
                        reloadUI()
                    }
                }
                return
            }
        }
    }
}
