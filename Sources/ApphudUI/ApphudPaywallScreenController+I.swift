//
//  ApphudPaywallScreenController+Internal.swift
//  Pods
//
//  Created by Renat Kurbanov on 19.05.2025.
//

import WebKit

extension ApphudPaywallScreenState: Equatable {
    public static func == (lhs: ApphudPaywallScreenState, rhs: ApphudPaywallScreenState) -> Bool {
        switch (lhs, rhs) {
        case (.loading, .loading), (.ready, .ready):
            return true
        case (.error, .error):
            return true // You can refine this if ApphudError is Equatable
        default:
            return false
        }
    }
}

extension ApphudPaywallScreenController {
        
    internal func load(maxTimeout: Double? = APPHUD_MAX_PAYWALL_LOAD_TIME) {
        startLoading()
        
        // Handle timeout
        if let timeout = maxTimeout {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if let self, self.state == .loading {
                    let e = ApphudError(message: "Failed to load paywall content within the specified timeout.", code: APPHUD_PAYWALL_LOAD_TIMEOUT)
                    self.handleFinishedLoading(error: e)
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
        
    private func startLoading() {
        guard let urlString = paywall.paywallURL,
              let url = URL(string: urlString) else {
            dismiss(animated: true)
            return
        }

        navigationDelegate = NavigationDelegateHelper()
        
        view.backgroundColor = .black
        
        paywallView.viewDelegate = self
        paywallView.navigationDelegate = navigationDelegate
        paywallView.load(URLRequest(url: url, cachePolicy: cachePolicy))
    }
    
    private func handleInfosAndViewLoaded() {
        if let productsInfo, isApphudViewLoaded {
            Task { [weak self] in

                guard let self else { return }

                self.paywallView.productsInfo = productsInfo
            }
        }
    }
    
    func apphudViewDidExecuteJS(error: (any Error)?) {
        handleFinishedLoading(error: error)
    }
    
    func handleFinishedLoading(error: (any Error)?) {
        guard self.state == .loading else { return }
        
        var aphError = error != nil ? ApphudError(error: error!) : nil
        
        if let nsError = error as? NSError, nsError.userInfo.description.contains("Can't find variable: PaywallSDK"), nsError.localizedDescription.contains("A JavaScript exception occurred") {
            aphError = ApphudError(message: "Invalid Paywall Screen URL: \(String(describing: paywall.paywallURL))", code: APPHUD_PAYWALL_SCREEN_INVALID)
        }
        
        self.state = aphError != nil ? .error(error: aphError!) : .ready
        
        self.delegate?.apphudPaywallScreenControllerDidFinishLoading(controller: self, error: aphError)

        if let cb = self.didLoadCallback {
            self.didLoadCallback = nil
            cb(aphError)
        }
    }
    
    internal func apphudViewHandleClose() {
        dismissNow(userAction: true)
    }
    
    private func dismissNow(userAction: Bool) {
        let shouldClose = self.delegate?.ApphudPaywallScreenControllerShouldDismiss(controller: self, userClosed: userAction) ?? true
        if shouldClose {
            self.delegate?.apphudPaywallScreenControllerWillDismiss(controller: self, userClosed: userAction)
            dismiss(animated: true)
        }
        
        if !userAction && Apphud.hasPremiumAccess() {
            ApphudScreensManager.shared.unloadPaywalls()
        }
    }
    
    @MainActor
    public func apphudViewHandlePurchase(index: Int) {
        let product = paywall.products[index]
        
        self.delegate?.apphudPaywallScreenControllerWillPurchase(controller: self, product: product)
        
        Apphud.purchase(product) { [weak self] result in
            if let self {
                self.delegate?.apphudPaywallScreenControllerPurchaseResult(controller: self, result: result)
                if result.success {
                    self.dismissNow(userAction: false)
                }
            }
        }
    }
    
    public func apphudViewDidLoad() {
        isApphudViewLoaded = true
        handleInfosAndViewLoaded()
    }
    
    public override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
    }
    
    public override func viewDidLoad() {
        super.viewDidLoad()
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        
        if !didTrackPaywallShown {
            didTrackPaywallShown = true
            Apphud.paywallShown(paywall)
        }
        
        ApphudScreensManager.shared.pendingPaywallControllers.removeValue(forKey: paywall.identifier)
        
        // preload the same paywall again for the next call
        Apphud.preloadPaywallScreen(paywall)
    }
    
    @MainActor
    internal func apphudViewHandleRestore() {
        self.delegate?.apphudPaywallScreenControllerWillRestore(controller: self)
        Apphud.restorePurchases { [weak self] result in
            
            if let self {
                self.delegate?.apphudPaywallScreenControllerRestoreResult(controller: self, result: result)
                if Apphud.hasPremiumAccess() {
                    self.dismissNow(userAction: false)
                }
            }
        }
    }
    
    internal class NavigationDelegateHelper: NSObject, WKNavigationDelegate {
        
        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            
            guard let aphView = webView as? ApphudView else {return }
                        
            aphView.viewDelegate?.apphudViewDidLoad()
        }
        
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            guard let aphView = webView as? ApphudView else {return }
            
            aphView.viewDelegate?.apphudViewDidExecuteJS(error: error)
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
