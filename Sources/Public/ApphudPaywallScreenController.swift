//
//  ApphudPaywallScreenController.swift
//  apphud
//

#if os(iOS)
import UIKit
import WebKit
import StoreKit

/// Specifies how paywalls are cached.
/// - `sandboxAndProduction`: Use cached paywalls in both sandbox and production environments.
/// - `productionOnly`: Always reload paywalls in sandbox, but cache them in production. Useful for testing, as remote changes will become visible immediately in sandbox.
public enum ApphudPaywallCachePolicy {
    case sandboxAndProduction
    case productionOnly
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

/// Represents the result of attempting to fetch and prepare a paywall screen for display.
public enum ApphudPaywallScreenFetchResult {

    /// The paywall screen was successfully fetched and is ready to be presented. You must manually show this controller.
    /// - Parameter controller: A fully initialized `ApphudPaywallScreenController` instance.
    case success(controller: ApphudPaywallScreenController)

    /// An error occurred while fetching or initializing the paywall screen.
    /// - Parameter error: The error describing what went wrong.
    case error(error: ApphudError)
}

public class ApphudPaywallScreenController: UIViewController, @preconcurrency ApphudViewDelegate {

    /// Apphud paywall object.
    public let paywall: ApphudPaywall

    /// Indicates whether the paywall controller has finished loading its content.
    public internal(set) var state: ApphudPaywallScreenState = .loading

    /**
     Indicated whether controller should dismiss automatically on close button tap or on successful purchase or restoration. Default is `true`.
     */
    public var shouldAutoDismiss = true
    
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

    /// Called when the user initiates a purchase or starts restoring purchases.
    ///
    /// By default, if `useSystemLoadingIndicator` is `true`, the SDK will automatically display a system loading indicator.
    /// To use your own custom loading indicator, set `useSystemLoadingIndicator = false` and handle the UI in this callback.
    ///
    /// - Parameter product: The `ApphudProduct` being purchased, or `nil` if the user initiated a restore action.
    public var onTransactionStarted: ((ApphudProduct?) -> Void)?

    /// Called when a purchase or restoration completes, either successfully or with a failure due to user cancellation or another error.
    ///
    /// By default, if `useSystemLoadingIndicator` is `true`, the SDK will automatically hide the system loading indicator.
    /// To use your own custom loading indicator, set `useSystemLoadingIndicator = false` and handle the UI in this callback.
    /// If the purchase or restoration succeeds, the controller will be automatically dismissed if `shouldAutoDismiss` is set to `true`.
    ///
    /// - Parameter result: An `ApphudPurchaseResult` containing details of the purchase, including the product, the error (if any),
    ///   the underlying `SKPaymentTransaction`, and the `userCanceled` flag.
    public var onTransactionCompleted: ((ApphudPurchaseResult) -> Void)?

    /// Called when the user finishes interacting with the paywall—either by completing a purchase successfully or by closing the paywall manually.
    ///
    /// If `shouldAutoDismiss` is set to `false`, you must manually close the paywall controller in this callback.
    public var onCloseButtonTapped: (() -> Void)?

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

    internal func onLoad(maxTimeout: TimeInterval = APPHUD_PAYWALL_SCREEN_LOAD_TIMEOUT,
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
}

#endif
