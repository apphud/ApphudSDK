//
//  ApphudPaywallController.swift
//  apphud
//

import UIKit
import WebKit
import StoreKit

/// A protocol that defines methods for handling paywall-related events and user interactions.
public protocol ApphudPaywallDelegate {
    
    /// Called when the paywall controller has finished loading and is ready to be displayed.
    /// - Parameter controller: The paywall controller instance that is now ready.
    func apphudPaywallControllerIsReady(controller: ApphudPaywallController)
    
    /// Called before a purchase is initiated through the paywall.
    /// - Parameters:
    ///   - controller: The paywall controller instance where the purchase is occurring.
    ///   - product: The product that will be purchased.
    func apphudPaywallControllerWillPurchase(controller: ApphudPaywallController, product: ApphudProduct)
    
    /// Called when a purchase attempt has completed with a result.
    /// - Parameters:
    ///   - controller: The paywall controller instance where the purchase occurred.
    ///   - result: The result of the purchase attempt.
    func apphudPaywallControllerPurchaseResult(controller: ApphudPaywallController, result: ApphudPurchaseResult)
    
    /// Called before a restore purchases operation is initiated.
    /// - Parameter controller: The paywall controller instance where the restore is occurring.
    func apphudPaywallControllerWillRestore(controller: ApphudPaywallController)
    
    /// Called when a restore purchases operation has completed with a result.
    /// - Parameters:
    ///   - controller: The paywall controller instance where the restore occurred.
    ///   - result: The result of the restore attempt.
    func apphudPaywallControllerRestoreResult(controller: ApphudPaywallController, result: ApphudRestoreResult)

    /// Called before the paywall controller is dismissed.
    /// - Parameters:
    ///   - controller: The paywall controller instance being dismissed.
    ///   - userAction: Whether the dismissal was triggered by tapping the close button.
    func apphudPaywallControllerWillDismiss(controller: ApphudPaywallController, userAction: Bool)
    
    /// Called to determine if the paywall controller should be dismissed.
    /// If developer returns false, the paywall will not be dismissed, which means that developer should handle the paywall dismissal manually.
    /// If not implemented, the paywall will be dismissed by default.
    /// - Parameters:
    ///   - controller: The paywall controller instance.
    ///   - userAction: Whether the dismissal was triggered by user action.
    /// - Returns: Boolean indicating whether the controller should be dismissed.
    func apphudPaywallControllerShouldDismiss(controller: ApphudPaywallController, userAction: Bool) -> Bool
    
    /// Called when the user attempts to navigate to an external URL from the paywall.
    /// - Parameters:
    ///   - controller: The paywall controller instance.
    ///   - url: The URL that will be opened.
    func apphudPaywallControllerWillNavigate(controller: ApphudPaywallController, url: URL)
}

public class ApphudPaywallController: UIViewController, @preconcurrency ApphudViewDelegate {

    /// Apphud paywall object.
    public private(set) var paywall: ApphudPaywall
    
    /// Returns true when the paywall controller has finished loading and is ready to be displayed.
    public internal(set) var isReady: Bool = false
    
    /// Delegate of the paywall controller
    public var delegate: ApphudPaywallDelegate?
    
    // MARK: - Internal methods below
    
    internal init(paywall: ApphudPaywall) {
        self.paywall = paywall
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal var readyCallback: ((ApphudError?) -> Void)?
    internal var isApphudViewLoaded = false
    internal var navigationDelegate: NavigationDelegateHelper?
    internal var productsInfo: [[String: any Sendable]]?
    internal lazy var paywallView: ApphudView = {
        return ApphudView.create(parentView: self.view)
    }()
}
