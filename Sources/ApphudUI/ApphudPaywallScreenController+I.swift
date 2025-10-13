//
//  ApphudPaywallScreenController+Internal.swift
//  Pods
//
//  Created by Renat Kurbanov on 19.05.2025.
//

#if os(iOS)

import WebKit
import SafariServices

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

extension ApphudPaywallScreenController: WKUIDelegate {

    internal func setMaxTimeout(maxTimeout: TimeInterval) {
        Task { [weak self] in
            try? await Task.sleep(nanoseconds: UInt64(maxTimeout * 1_000_000_000))
            if let self, self.state == .loading {
                let e = ApphudError(message: "Failed to load paywall content within the specified timeout.", code: APPHUD_PAYWALL_LOAD_TIMEOUT)
                await self.handleFinishedLoading(error: e)
            }
        }
    }

    internal func load() {

        startLoading()

        Task { [weak self] in
            if let infos = await self?.productsInfo() {
                self?.productsInfo = infos
                self?.handleInfosAndViewLoaded()
            }
        }
    }

    @MainActor
    private func productsInfo() async -> [[String: any Sendable]]? {

        _ = await ApphudInternal.shared.performWhenStoreKitProductFetched(maxAttempts: 1)

        await paywall.renderPropertiesIfNeeded()

        var infos = [[String: any Sendable]]()

        for p in paywall.products {
            if let skProduct = p.skProduct {

                var finalInfo = skProduct.apphudSubmittableParameters()

                if let props = p.jsonProperties() {
                    finalInfo.merge(props, uniquingKeysWith: { _, new in new })
                }
                finalInfo.removeValue(forKey: "promo_offers")

                infos.append(finalInfo)
            } else {
                infos.append([:])
            }
        }

        return infos
    }

    private func startLoading() {
        guard let url = paywall.screen?.paywallURL else {
            dismiss(animated: true)
            return
        }

        navigationDelegate = NavigationDelegateHelper()

        view.backgroundColor = .black

        paywallView.viewDelegate = self
        paywallView.navigationDelegate = navigationDelegate
        paywallView.uiDelegate = self
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
        Task { await handleFinishedLoading(error: error) }
    }

    func handleFinishedLoading(error: (any Error)?) async {
        guard self.state == .loading else { return }

        var aphError = error != nil ? ApphudError(error: error!) : nil

        if let nsError = error as? NSError, nsError.userInfo.description.contains("Can't find variable: PaywallSDK"), nsError.localizedDescription.contains("A JavaScript exception occurred") {
            aphError = ApphudError(message: "Invalid Paywall Screen URL: \(String(describing: paywall.screen?.paywallURL))", code: APPHUD_PAYWALL_SCREEN_INVALID)
        }

        self.state = aphError != nil ? .error(error: aphError!) : .ready

        if aphError == nil {
            try? await Task.sleep(nanoseconds: 300_000_000)
        }

        if let cb = self.didLoadCallback {
            self.didLoadCallback = nil
            cb(aphError)
        }

        if self.state == .ready {
            apphudLog("Screen is ready")
        }
    }

    internal func apphudViewHandleClose() {
        onCloseButtonTapped?()
        if shouldAutoDismiss {
            dismissNow(userAction: true)
        }
    }

    private func dismissNow(userAction: Bool) {

        if self.shouldPopOnDismiss, let nc = navigationController {
            nc.popViewController(animated: true)
        } else {
            dismiss(animated: true)
        }

        if !userAction && Apphud.hasPremiumAccess() {
            ApphudScreensManager.shared.unloadPaywalls()
        }
    }

    @MainActor
    public func apphudViewHandlePurchase(index: Int) {

        guard index >= 0 && index < paywall.products.count else {
            apphudLog("Invalid product index \(index), only \(paywall.products.count) products available", forceDisplay: true)
            return
        }

        let product = paywall.products[index]
        self.onTransactionStarted?(product)
        if self.useSystemLoadingIndicator {
            showLoadingIndicator()
        }
        
        ApphudInternal.shared.purchase(productId: product.productId, product: product, validate: true, purchasingFromScreen: true) { [weak self] result in
            if let self {
                self.hideLoadingIndicator()
                self.onTransactionCompleted?(result)
                if result.success && self.shouldAutoDismiss {
                    self.dismissNow(userAction: false)
                }
            }
        }
    }
    
    @MainActor
    internal func apphudViewHandleRestore() {

        self.onTransactionStarted?(nil)
        if self.useSystemLoadingIndicator {
            self.showLoadingIndicator()
        }

        Apphud.restorePurchases { [weak self] result in
            if let self {
                self.hideLoadingIndicator()
                self.onTransactionCompleted?(result)
                if result.success && self.shouldAutoDismiss {
                    self.dismissNow(userAction: false)
                }
            }
        }
    }

    func showLoadingIndicator() {
        loadingView.startLoading(in: self.view) // auto-dismisses in 30 seconds
    }

    func hideLoadingIndicator() {
        // Manually dismiss if needed
        loadingView.finishLoading()
    }

    public func apphudViewDidLoad() {
        isApphudViewLoaded = true
        handleInfosAndViewLoaded()
        apphudLog("Paywall View did load")
    }

    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if !didTrackPaywallShown {
            didTrackPaywallShown = true
            Apphud.paywallShown(paywall)
        }

        ApphudScreensManager.shared.unloadPaywalls(paywall.identifier)
        apphudLog("Paywall View did appear")
    }

    public override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)
        if !Apphud.hasPremiumAccess() {
            // preload the same paywall again for the next call
            ApphudScreensManager.shared.preloadPaywall(paywall)
        }
    }

    func apphudViewShouldLoad(url: URL) -> Bool {
        if paywall.screen?.paywallURL?.host == url.host {
            return true
        } else {
            if self.onShouldOpenURL?(url) ?? true {
                let controller = SFSafariViewController(url: url)
                self.present(controller, animated: true)
            }
            return false
        }
    }

    public func webView(_ webView: WKWebView,
                     createWebViewWith configuration: WKWebViewConfiguration,
                     for navigationAction: WKNavigationAction,
                     windowFeatures: WKWindowFeatures) -> WKWebView? {
        if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
            if url.host == "pay.apphud.com" {
                webView.load(navigationAction.request)
            } else {
                _ = apphudViewShouldLoad(url: url)
            }
        }
        return nil
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

            guard let url = navigationAction.request.url else { return .allow }

            if url.host == "pay.apphud.com" {
                if url.lastPathComponent == "restore" {
                    aphView.viewDelegate?.apphudViewHandleRestore()
                } else if url.lastPathComponent == "close" {
                    aphView.viewDelegate?.apphudViewHandleClose()
                } else if url.absoluteString.contains("/purchase/") {
                    let index = url.lastPathComponent
                    if index.count > 0, let int = Int(index), int >= 0 {
                        aphView.viewDelegate?.apphudViewHandlePurchase(index: int)
                    }
                }

                return .cancel
            } else if aphView.viewDelegate?.apphudViewShouldLoad(url: url) ?? true {
                return .allow
            }

            return .cancel
        }
    }
}

#endif
