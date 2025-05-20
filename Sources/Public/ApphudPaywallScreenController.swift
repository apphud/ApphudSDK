//
//  ApphudPaywallScreenController.swift
//  apphud
//

import UIKit
import WebKit
import StoreKit

/// A protocol that defines methods for handling paywall-related events and user interactions.
public protocol ApphudPaywallScreenDelegate {
    
    /// Called when the paywall controller finishes loading its content.
    /// This method will not be triggered if the controller was already in a loaded state when the delegate was assigned.
    /// Check the `state` property to determine the current loading state.
    /// - Parameter controller: The instance of `ApphudPaywallScreenController`. If `error` is `nil`, the paywall loaded successfully.
    /// - Parameter error: An optional error indicating that the paywall failed to load.
    func apphudPaywallScreenControllerDidFinishLoading(controller: ApphudPaywallScreenController, error: ApphudError?)
    
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

/// Represents the current loading state of a paywall screen.
public enum ApphudPaywallScreenState {
    
    /// The paywall is currently loading its content.
    case loading
    
    /// The paywall has finished loading and is ready to be displayed.
    case ready
    
    /// An error occurred while loading the paywall.
    ///
    /// This state indicates that the content could not be loaded due to a network issue,
    /// invalid paywall URL, or another error. Developer should show default paywall instead.
    ///
    /// - Parameter error: The error describing the failure.
    case error(error: ApphudError)
}

public class ApphudPaywallScreenController: UIViewController, @preconcurrency ApphudViewDelegate {

    /// Apphud paywall object.
    public let paywall: ApphudPaywall
    
    /// Indicates whether the paywall controller has finished loading its content.
    public internal(set) var state: ApphudPaywallScreenState = .loading

    /// Sets a callback to be triggered when the paywall controller finishes loading.
    ///
    /// If the controller is still loading, the callback will be stored and called later.
    /// If loading is already complete, the callback is called immediately with either `nil` (success) or an `ApphudError` (failure).
    ///
    /// Use the `state` property to check the current loading status.
    ///
    /// - Parameters:
    ///   - maxTimeout: Maximum time to wait before triggering a timeout error starting from method call. Default value is 5.0 seconds.
    ///   - callback: Called with `nil` on success or an `ApphudError` on failure.
    public func didLoadCallback(maxTimeout: TimeInterval = APPHUD_PAYWALL_SCREEN_LOAD_TIMEOUT,
                                callback: ((ApphudError?) -> Void)?) {
        switch state {
        case .loading:
            setMaxTimeout(maxTimeout: maxTimeout)
            self.didLoadCallback = callback
        case .ready:
            callback?(nil)
        case .error(let error):
            callback?(error)
        }
    }

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
    
    internal var didLoadCallback: ((ApphudError?) -> Void)?
    internal var isApphudViewLoaded = false
    internal var navigationDelegate: NavigationDelegateHelper?
    internal var cachePolicy: NSURLRequest.CachePolicy = .returnCacheDataElseLoad
    internal var productsInfo: [[String: any Sendable]]?
    internal lazy var paywallView: ApphudView = {
        return ApphudView.create(parentView: self.view)
    }()
    internal var didTrackPaywallShown = false
}
