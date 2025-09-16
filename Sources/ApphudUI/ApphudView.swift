//
//  ApphudView.swift
//  Pods
//
//  Created by Renat Kurbanov on 14.05.2025.
//

#if os(iOS)
import UIKit
import WebKit

internal protocol ApphudViewDelegate {
    func apphudViewHandleClose()
    func apphudViewHandlePurchase(index: Int)
    func apphudViewHandleRestore()
    func apphudViewDidLoad()
    func apphudViewShouldLoad(url: URL) -> Bool
    func apphudViewDidExecuteJS(error: Error?)
}

internal class ApphudView: WKWebView {

    var viewDelegate: ApphudViewDelegate?

    var productsInfo: [[String: Any]]? {
        didSet {
            if let productsInfo {
                replaceProductsInfo(infos: productsInfo)
            }
        }
    }

    static func create(parentView: UIView) -> ApphudView {

        let config = WKWebViewConfiguration()
        if #available(iOS 14.5, *) {
            config.preferences.isTextInteractionEnabled = false
            config.mediaTypesRequiringUserActionForPlayback = []
            config.allowsInlineMediaPlayback = true
        }

        let wv = ApphudView(frame: UIScreen.main.bounds, configuration: config)
        parentView.addSubview(wv)
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
            wv.topAnchor.constraint(equalTo: parentView.topAnchor),
            wv.leadingAnchor.constraint(equalTo: parentView.leadingAnchor),
            wv.trailingAnchor.constraint(equalTo: parentView.trailingAnchor),
            wv.bottomAnchor.constraint(equalTo: parentView.bottomAnchor)
        ])
        wv.scrollView.showsVerticalScrollIndicator = false
        wv.clipsToBounds = false

        return wv
    }

    public func replaceProductsInfo(infos: [[String: any Sendable]]) {
        
        let urlString = self.url?.absoluteString ?? ""
        
        if (urlString.contains("demo=true") && urlString.contains("preview=true")) {
            self.viewDelegate?.apphudViewDidExecuteJS(error: nil)
            return
        }
        
        guard let jsonData = try? JSONSerialization.data(withJSONObject: infos, options: []),
              let jsonString = String(data: jsonData, encoding: .utf8) else {
            print("Failed to serialize infos to JSON")
            return
        }

        evaluateJavaScript("PaywallSDK.shared().processDomMacros(\(jsonString));") { [weak self] result, error in

            guard let self = self else {return}

            if let error {
                self.viewDelegate?.apphudViewDidExecuteJS(error: error)

            } else {
                let insets = getSafeAreaInsets()
                self.evaluateJavaScript("PaywallSDK.shared().applyCustomInsets(\(insets.top), \(insets.bottom));") { [weak self] _, error in
                    guard let self = self else {return}

                    self.viewDelegate?.apphudViewDidExecuteJS(error: nil)
                }
            }
        }
    }

    func getSafeAreaInsets() -> UIEdgeInsets {
        if #available(iOS 13.0, *) {
            return UIApplication.shared
                .connectedScenes
                .compactMap { $0 as? UIWindowScene }
                .flatMap { $0.windows }
                .first(where: \.isKeyWindow)?
                .safeAreaInsets ?? .zero
        } else {
            return UIApplication.shared.keyWindow?.safeAreaInsets ?? .zero
        }
    }
}

#endif
