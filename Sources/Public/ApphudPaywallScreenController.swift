//
//  ApphudPaywallScreenController.swift
//  apphud
//

import UIKit
import WebKit
import StoreKit

/// A protocol that defines methods for handling paywall-related events and user interactions.
public protocol ApphudPaywallScreenDelegate {
    /// Called before a purchase is initiated through the paywall.
    /// - Parameters:
    ///   - controller: The paywall controller instance where the purchase is occurring.
    ///   - product: The product that will be purchased.
    func apphudPaywallScreenInitiatePurchase(controller: ApphudPaywallScreenController, product: ApphudProduct)
        
    /// Called before a restore purchases operation is initiated.
    /// - Parameter controller: The paywall controller instance where the restore is occurring.
    func apphudPaywallScreenInitiateRestore(controller: ApphudPaywallScreenController)
    
    /// Called when the user attempts to open external URL from the paywall. Default is `true`. Return `false` if you want to handle this manually.
    /// SDK will open URL in SFSafariViewController.
    /// - Parameters:
    ///   - controller: The paywall controller instance.
    ///   - url: The URL that will be opened.
    func apphudPaywallScreenShouldOpen(url: URL, controller: ApphudPaywallScreenController) -> Bool
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

public enum ApphudPaywallResult {
    case purchased(result: ApphudPurchaseResult)
    case restored
    case canceled
}

public enum ApphudPaywallDismissPolicy {
    case allow
    case cancel
}

public class ApphudPaywallScreenController: UIViewController, @preconcurrency ApphudViewDelegate {

    /// Apphud paywall object.
    public let paywall: ApphudPaywall
    
    /// Delegate of the paywall controller
    public var delegate: ApphudPaywallScreenDelegate?
    
    public var completionHandler: ((ApphudPaywallResult) -> ApphudPaywallDismissPolicy)?
    
    /// Sets a callback to be triggered when the paywall controller finishes loading.
    ///
    /// If the controller is still loading, the callback will be stored and called later.
    /// If loading is already complete, the callback is called immediately with either `nil` (success) or an `ApphudError` (failure).
    ///
    /// Use the `state` property to check the current loading status.
    ///
    /// - Parameters:
    ///   - maxTimeout: Maximum time to wait before triggering a timeout error starting from method call. Default is `APPHUD_PAYWALL_SCREEN_LOAD_TIMEOUT`.
    ///   - callback: Called with `nil` on success or an `ApphudError` on failure.
    public func didLoadHandler(maxTimeout: TimeInterval = APPHUD_PAYWALL_SCREEN_LOAD_TIMEOUT,
                                handler: ((ApphudError?) -> Void)?) {
        switch state {
        case .loading:
            setMaxTimeout(maxTimeout: maxTimeout)
            self.didLoadCallback = handler
        case .ready:
            handler?(nil)
        case .error(let error):
            handler?(error)
        }
    }
    
    /// Indicates whether the paywall controller has finished loading its content.
    public internal(set) var state: ApphudPaywallScreenState = .loading
    
    /**
     Indicates whether controller should pop the navigation stack instead of being dismissed modally.
     */
    public var shouldPopOnDismiss = false
        
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
