//
//  ApphudPaywallController.swift
//  apphud
//

import UIKit
import WebKit

public class ApphudPaywallController: UIViewController, @preconcurrency ApphudViewDelegate {
    
    // MARK: - Public methods below
    
    /**
     Instance of a ApphudPaywall.
     */
    var paywall: ApphudPaywall
    
    /**
     Creates an instance of `ApphudPaywallController` with the specified paywall.

     This method verifies that the provided `ApphudPaywall` contains a visual paywall URL.
     If the paywall does not contain a visual URL, an `ApphudError` is thrown.

     - Parameter paywall: The `ApphudPaywall` object used to configure the view controller.
     - Throws: `ApphudError` if the paywall has no visual URL.
     - Returns: A fully configured instance of `ApphudPaywallController`.

     Example:
     ```swift
     do {
         let vc = try ApphudPaywallController.create(paywall: paywall)
         present(vc, animated: true)
     } catch {
         print("Failed to create paywall screen: \(error)")
     }
     ```
     */
    public static func create(paywall: ApphudPaywall) throws -> ApphudPaywallController {
        guard paywall.hasVisualPaywall() else {
            throw ApphudError(message: "Paywall \(paywall.identifier) has no visual URL", code: APPHUD_NO_VISUAL_PAYWALL)
        }
        return ApphudPaywallController(paywall: paywall)
    }
    
    /**
     Preloads the paywall content and product information asynchronously.
     
     This method initiates the loading of both the visual paywall content and associated product information.
     It provides a way to prepare the paywall before displaying it to the user, ensuring a smoother presentation.
     
     - Parameters:
        - maxTimeout: Maximum time (in seconds) to wait for the paywall to load. If not specified, defaults to `APPHUD_MAX_PAYWALL_LOAD_TIME`.
                     After this timeout, the callback will be called with `false` if the loading hasn't completed.
        - callback: A closure that is called exactly once, either:
                  - with `true` when both the paywall content and products are successfully loaded
                  - with `false` when the timeout is reached before loading completes
     
     - Note: The callback is guaranteed to be called only once, either on successful load or timeout, whichever comes first.
     
     Example usage:
     ```swift
     paywallController.preload(maxTimeout: 5.0) { success in
         if success {
             // Paywall is ready to be presented
             present(paywallController, animated: true)
         } else {
             // Loading timed out, handle the error
         }
     }
     ```
     */
    public func preload(maxTimeout: Double? = APPHUD_MAX_PAYWALL_LOAD_TIME, callback: @escaping (Bool) -> Void) {
        self.readyCallback = callback
        startLoading()
        
        // Handle timeout
        if let timeout = maxTimeout {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if let cb = self?.readyCallback {
                    self?.readyCallback = nil
                    cb(false)
                }
            }
        }
        
        Task { [weak self] in
            if let infos = await self?.productsInfo() {
                self?.productsInfo = infos
                self?.handleInfosAndViewLoaded()
            }
        }
    }

    /**
     Creates and preloads an instance of `ApphudPaywallController` with the specified paywall.

     This method creates a paywall controller and immediately starts preloading its content.
     It verifies that the provided `ApphudPaywall` contains a visual paywall URL and initiates
     loading of both the visual content and product information.

     - Parameters:
        - paywall: The `ApphudPaywall` object used to configure the view controller.
        - maxTimeout: Maximum time (in seconds) to wait for the paywall to load. If not specified, defaults to `APPHUD_MAX_PAYWALL_LOAD_TIME`.
        - completion: A closure that is called exactly once with either:
                    - `(controller, true)` when both the paywall content and products are successfully loaded
                    - `(controller, false)` when the timeout is reached before loading completes
     - Throws: `ApphudError` if the paywall has no visual URL.

     Example:
     ```swift
     do {
         try ApphudPaywallController.createAndPreload(paywall: paywall) { controller, ready in
             if ready {
                 // Paywall is ready to be presented
                 present(controller, animated: true)
             } else {
                 // Loading timed out, handle the error
             }
         }
     } catch {
         print("Failed to create paywall screen: \(error)")
     }
     ```
     */
    public static func createAndPreload(
        paywall: ApphudPaywall,
        maxTimeout: Double? = APPHUD_MAX_PAYWALL_LOAD_TIME,
        completion: @escaping (ApphudPaywallController, Bool) -> Void
    ) throws {
        let controller = try create(paywall: paywall)
        controller.preload(maxTimeout: maxTimeout) { success in
            completion(controller, success)
        }
    }

    // MARK: - Private methods below
    
    private var readyCallback: ((Bool) -> Void)?
    
    private init(paywall: ApphudPaywall) {
        self.paywall = paywall
        super.init(nibName: nil, bundle: nil)
        self.modalPresentationStyle = .fullScreen
    }
    
    private lazy var paywallView: ApphudView = {
        
        let wv = ApphudView(frame: UIScreen.main.bounds)
        self.view.addSubview(wv)
        wv.backgroundColor = .white
        wv.allowsLinkPreview = false
        wv.allowsBackForwardNavigationGestures = false
        wv.scrollView.layer.masksToBounds = false
        wv.scrollView.contentInsetAdjustmentBehavior = .never
        wv.isOpaque = false
        wv.scrollView.isOpaque = false
        wv.backgroundColor = UIColor.clear
        wv.scrollView.backgroundColor = UIColor.clear
        wv.scrollView.alwaysBounceVertical = false
        wv.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            wv.topAnchor.constraint(equalTo: self.view.topAnchor),
            wv.leadingAnchor.constraint(equalTo: self.view.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: self.view.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: self.view.bottomAnchor)
        ])
        wv.scrollView.showsVerticalScrollIndicator = false
        wv.clipsToBounds = false
        
        return wv
    }()
    
    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
        
    @MainActor
    private func productsInfo() async -> [[String: any Sendable]]? {
        return await withCheckedContinuation { continuation in
            ApphudInternal.shared.performWhenStoreKitProductFetched(maxAttempts: 1) { [weak self] _ in
                var infos = [[String: any Sendable]]()
                for p in self?.paywall.products ?? [] {
                    if let skProduct = p.skProduct {
                                                
                        var finalInfo = skProduct.apphudSubmittableParameters()
                        
                        let langCode = Locale.current.languageCode ?? "en"
                        var innerProps: ApphudAnyCodable?
                        if let props = p.properties {
                            if props[langCode] != nil {
                                innerProps = props[langCode]
                            } else {
                                innerProps = props["en"]
                            }
                        }
                        
                        if let innerProps = innerProps?.value as? [String: ApphudAnyCodable] {
                            let jsonProps = innerProps.mapValues { $0.toJSONValue() }
                            finalInfo.merge(jsonProps, uniquingKeysWith: { old, new in new })
                        }
                        
                        finalInfo.removeValue(forKey: "promo_offers")
                        
                        infos.append(finalInfo)
                    } else {
                        infos.append([:])
                    }
                }
                continuation.resume(returning: infos)
            }
        }
    }
    
    private var navigationDelegate: NavigationDelegateHelper?
    
    private var productsInfo: [[String: any Sendable]]?
    
    private func startLoading() {
        guard let urlString = paywall.paywallURL,
              let url = URL(string: urlString) else {
            dismiss(animated: true)
            return
        }

        navigationDelegate = NavigationDelegateHelper()
        
        view.backgroundColor = .purple
        
        paywallView.viewDelegate = self
        paywallView.navigationDelegate = navigationDelegate
        paywallView.load(URLRequest(url: url, cachePolicy: Apphud.isSandbox() ? .reloadIgnoringCacheData : .returnCacheDataElseLoad))
    }
    
    private func handleInfosAndViewLoaded() {
        if let productsInfo, isApphudViewLoaded {
            Task {
                paywallView.productsInfo = productsInfo
                view.viewWithTag(1000)?.removeFromSuperview()
                if let cb = self.readyCallback {
                    self.readyCallback = nil
                    cb(true)
                }
            }
        }
    }
    
    public func apphudViewHandleClose() {
        dismiss(animated: true)
    }
    
    private var isApphudViewLoaded = false
    
    @MainActor
    public func apphudViewHandlePurchase(index: Int) {
        let product = paywall.products[index]
        
        Apphud.purchase(product) { result in
            if result.success {
                self.dismiss(animated: true)
            }
        }
    }
    
    public func apphudViewDidLoad() {
        isApphudViewLoaded = true
        handleInfosAndViewLoaded()
    }
    
    @MainActor
    public func apphudViewHandleRestore() {
        Apphud.restorePurchases { _, _, _ in
            if Apphud.hasPremiumAccess() {
                self.dismiss(animated: true)
            }
        }
    }
    
    private class NavigationDelegateHelper: NSObject, WKNavigationDelegate {
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            
            guard let aphView = webView as? ApphudView else {return }
            
            aphView.viewDelegate?.apphudViewDidLoad()
        }
        
        func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction) async -> WKNavigationActionPolicy {
            
            guard let aphView = webView as? ApphudView else {return .cancel }
            
            if navigationAction.request.url?.lastPathComponent == "close" {
                aphView.viewDelegate?.apphudViewHandleClose()
                return .cancel
            } else if (navigationAction.request.url?.host == "pay.apphud.com") {
                if navigationAction.request.url?.lastPathComponent == "restore" {
                    aphView.viewDelegate?.apphudViewHandleRestore()
                } else {
                    let index = navigationAction.request.url?.absoluteString.suffix(1)
                    if let index = index, let intValue = Int(index) {
                        aphView.viewDelegate?.apphudViewHandlePurchase(index: intValue)
                    }
                }
                
                return .cancel
            }
            
            return .allow
        }
    }
}
