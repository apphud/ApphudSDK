//
//  ApphudView.swift
//  Pods
//
//  Created by Renat Kurbanov on 14.05.2025.
//

import UIKit
import WebKit

public protocol ApphudViewDelegate {
    func apphudViewHandleClose()
    func apphudViewHandlePurchase(index: Int)
    func apphudViewHandleRestore()
    func apphudViewDidLoad()
}

public class ApphudView: WKWebView {
    
    var viewDelegate: ApphudViewDelegate?
    
    var productsInfo: [[String: Any]]? {
        didSet {
            if let productsInfo {
                replaceProductsInfo(infos: productsInfo)
            }
        }
    }
    
    public func replaceProductsInfo(infos: [[String: any Sendable]]) {
        guard let jsonData = try? JSONSerialization.data(withJSONObject: infos, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("Failed to serialize infos to JSON")
            return
        }
        
        print("[ApphudView] Will execute JS:\n\n\(jsonString)")
        
        evaluateJavaScript("PaywallSDK.shared().processDomMacros(\(jsonString));") { result, error in
            if let error {
                print("[ApphudView] Failed to execute JS: \(error.localizedDescription)")
            } else {
                print("[ApphudView] Executed JS successfully: \(String(describing: result))")
            }
        }
    }
    
}
