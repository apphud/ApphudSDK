//
//  ApphudPaywallScreenController.swift
//  apphud
//

import UIKit
import WebKit
import StoreKit

/// A protocol that defines methods for handling paywall-related events and user interactions.
public protocol ApphudPaywallScreenDelegate {
    
    /// Called when the paywall controller has finished loading its content.
    /// This delegate method will not be called if controller already in a ready state by the time you set a delegate. See `isReady` property.
    /// - Parameter controller: The paywall controller instance that is now ready.
    func apphudPaywallScreenControllerIsReady(controller: ApphudPaywallScreenController)
    
    /// Called before a purchase is initiated through the paywall.
    /// - Parameters:
    ///   - controller: The paywall controller instance where the purchase is occurring.
    ///   - product: The product that will be purchased.
    func apphudPaywallScreenControllerWillPurchase(controller: ApphudPaywallScreenController, product: ApphudProduct)
    
    /// Called when a purchase attempt has completed with a result.
    /// - Parameters:
    ///   - controller: The paywall controller instance where the purchase occurred.
    ///   - result: The result of the purchase attempt.
    func apphudPaywallScreenControllerPurchaseResult(controller: ApphudPaywallScreenController, result: ApphudPurchaseResult)
    
    /// Called before a restore purchases operation is initiated.
    /// - Parameter controller: The paywall controller instance where the restore is occurring.
    func apphudPaywallScreenControllerWillRestore(controller: ApphudPaywallScreenController)
    
    /// Called when a restore purchases operation has completed with a result.
    /// - Parameters:
    ///   - controller: The paywall controller instance where the restore occurred.
    ///   - result: The result of the restore attempt.
    func apphudPaywallScreenControllerRestoreResult(controller: ApphudPaywallScreenController, result: ApphudRestoreResult)
    
    /// Called to determine if the paywall controller should be dismissed.
    /// If developer returns false, the paywall will not be dismissed, which means that developer should handle the paywall dismissal manually.
    /// If not implemented, the paywall will be dismissed by default.
    /// - Parameters:
    ///   - controller: The paywall controller instance.
    ///   - userClosed: Whether the dismissal was triggered by tapping the close button.
    /// - Returns: Boolean indicating whether the controller should be dismissed.
    func ApphudPaywallScreenControllerShouldDismiss(controller: ApphudPaywallScreenController, userClosed: Bool) -> Bool

    /// Called before the paywall controller is dismissed.
    /// - Parameters:
    ///   - controller: The paywall controller instance being dismissed.
    ///   - userClosed: Whether the dismissal was triggered by tapping the close button.
    func apphudPaywallScreenControllerWillDismiss(controller: ApphudPaywallScreenController, userClosed: Bool)
    
    /// Called when the user attempts to navigate to an external URL from the paywall.
    /// - Parameters:
    ///   - controller: The paywall controller instance.
    ///   - url: The URL that will be opened.
    func apphudPaywallScreenControllerWillNavigate(controller: ApphudPaywallScreenController, url: URL)
}

public class ApphudPaywallScreenController: UIViewController, @preconcurrency ApphudViewDelegate {

    /// Apphud paywall object.
    public let paywall: ApphudPaywall
    
    /// Indicates whether the paywall controller has finished loading its content.
    /// You can still present the screen even if it's not fully loaded — a loading skeleton will be displayed until the content is ready.
    public internal(set) var isReady: Bool = false

    /// Invoked when the paywall controller has finished loading its content. Returns an error if something went wrong during loading.
    /// You can still present the screen even if it's not fully loaded — a loading skeleton will be displayed until the content is ready.
    public var readyCallback: ((ApphudError?) -> Void)?
    
    /// Delegate of the paywall controller
    public var delegate: ApphudPaywallScreenDelegate?
        
    // MARK: - Internal methods below
    
    internal init(paywall: ApphudPaywall) {
        self.paywall = paywall
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
    
    internal var isApphudViewLoaded = false
    internal var navigationDelegate: NavigationDelegateHelper?
    internal var cachePolicy: NSURLRequest.CachePolicy = .returnCacheDataElseLoad
    internal var productsInfo: [[String: any Sendable]]?
    internal lazy var paywallView: ApphudView = {
        return ApphudView.create(parentView: self.view)
    }()
    internal var didTrackPaywallShown = false
}
