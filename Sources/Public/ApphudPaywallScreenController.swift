//
//  ApphudPaywallScreenController.swift
//  apphud
//

import UIKit
import WebKit
import StoreKit

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

/// Represents the result of attempting to fetch and prepare a paywall screen for display.
public enum ApphudPaywallScreenFetchResult {
    
    /// The paywall screen was successfully fetched and is ready to be presented.
    /// - Parameter controller: A fully initialized `ApphudPaywallScreenController` instance.
    case success(controller: ApphudPaywallScreenController)
    
    /// An error occurred while fetching or initializing the paywall screen.
    /// - Parameter error: The error describing what went wrong.
    case error(error: ApphudError)
}

/// Represents the result of a user's interaction with the paywall screen.
public enum ApphudPaywallResult {
    
    /// The user successfully completed a purchase or restored a previous active subscription or non-renewing purchase.
    /// - Parameter result: The result of the purchase, including transaction details.
    case success(ApphudPurchaseResult)
    
    /// Indicates that the purchase was either canceled by the user, failed due to an error,
    /// or no active subscription or non-renewing purchase was found during a restore attempt.
    /// - Parameter error: The error describing the reason for failure.
    case failure(Error)
    
    /// The user tapped on a close button.
    case userClosed
}

/// Defines whether the paywall screen should be dismissed after user interaction.
public enum ApphudPaywallDismissPolicy {
    
    /// The paywall screen should be dismissed.
    case allow
    
    /// The paywall screen should remain visible.
    case cancel
}

public class ApphudPaywallScreenController: UIViewController, @preconcurrency ApphudViewDelegate {

    /// Apphud paywall object.
    public let paywall: ApphudPaywall
    
    /// Indicates whether the paywall controller has finished loading its content.
    public internal(set) var state: ApphudPaywallScreenState = .loading
    
    /**
     Indicates whether controller should pop the navigation stack instead of being dismissed modally.
     */
    public var shouldPopOnDismiss = false
    
    /// Determines whether the SDK should display a system loading indicator during purchase or restore actions.
    ///
    /// If set to `true` (default), the SDK will automatically show and hide a system-provided loading spinner
    /// while a transaction is in progress.
    ///
    /// Set this to `false` if you want to show a custom loading indicator using the `onTransactionStarted` callback.
    public var useSystemLoadingIndicator: Bool = true

    /// Called when the user finishes interacting with the paywall.
    ///
    /// Use this to handle purchases, failures, or user cancellations.
    /// Return a `ApphudPaywallDismissPolicy` to determine whether the paywall should be dismissed.
    ///
    /// - Parameter result: The result of the user's interaction.
    /// - Returns: A dismiss policy indicating whether the paywall should be closed.
    public var onFinished: ((ApphudPaywallResult) -> ApphudPaywallDismissPolicy)?

    /// Called when the paywall finishes loading its content.
    ///
    /// If loading is still in progress, the handler will be stored and called later.
    /// If loading is already complete, it's called immediately with either `nil` (success)
    /// or an `ApphudError` (failure).
    ///
    /// - Parameters:
    ///   - maxTimeout: Maximum time to wait before triggering a timeout error. Default is `APPHUD_PAYWALL_SCREEN_LOAD_TIMEOUT`.
    ///   - handler: Called with `nil` on success or an `ApphudError` on failure.
    public func onLoad(maxTimeout: TimeInterval = APPHUD_PAYWALL_SCREEN_LOAD_TIMEOUT,
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

    /// Called when the user initiates a purchase or starts restoring purchases.
    ///
    /// By default, if `useSystemLoadingIndicator` is `true`, the SDK will display a system loading indicator automatically.
    /// If you want to show your own custom loading indicator, set `useSystemLoadingIndicator = false` and handle the UI in this callback.
    ///
    /// - Parameter product: The `ApphudProduct` being purchased, or `nil` if the user initiated a restore action.
    public var onTransactionStarted: ((ApphudProduct?) -> Void)?
    
    /// A callback that is triggered when the user taps a link that would open an external URL from the paywall.
    ///
    /// By default, the SDK opens the URL in a `SFSafariViewController`.
    /// Return `false` to override this behavior and handle the URL manually.
    ///
    /// - Parameters:
    ///   - url: The external URL the user tapped.
    /// - Returns: `true` to allow the SDK to open the URL automatically, `false` to prevent it.
    public var onShouldOpenURL: ((URL) -> Bool)?
        
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
    
    internal let loadingView = ApphudLoadingView()
}
