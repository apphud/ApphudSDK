//
//  ApphudPaywallController.swift
//  apphud
//

import UIKit
import WebKit

public class ApphudPaywallController: UIViewController, @preconcurrency ApphudViewDelegate {

    public internal(set) var paywall: ApphudPaywall
    internal private(set) var isReady: Bool = false
    
    // MARK: - Private methods below
    
    internal func preload(maxTimeout: Double? = APPHUD_MAX_PAYWALL_LOAD_TIME, callback: @escaping (ApphudError?) -> Void) {
        self.readyCallback = callback
        startLoading()
        
        // Handle timeout
        if let timeout = maxTimeout {
            Task { [weak self] in
                try? await Task.sleep(nanoseconds: UInt64(timeout * 1_000_000_000))
                if let cb = self?.readyCallback {
                    self?.readyCallback = nil
                    let e = ApphudError(message: "Failed to load paywall content within the specified timeout", code: APPHUD_PAYWALL_LOAD_TIMEOUT)
                    cb(e)
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
   
    private var readyCallback: ((ApphudError?) -> Void)?
    
    internal init(paywall: ApphudPaywall) {
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
        paywallView.load(URLRequest(url: url,
                                    cachePolicy: /*Apphud.isSandbox() ? .reloadIgnoringCacheData :*/ .returnCacheDataElseLoad))
    }
    
    private func handleInfosAndViewLoaded() {
        if let productsInfo, isApphudViewLoaded {
            Task {
                paywallView.productsInfo = productsInfo
                view.viewWithTag(1000)?.removeFromSuperview()
                if let cb = self.readyCallback {
                    self.readyCallback = nil
                    cb(nil)
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
    
    public override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)
        ApphudRulesManager.shared.pendingPaywallControllers.removeValue(forKey: paywall.identifier)
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
