//
//  ApphudWebController.swift
//  Pods
//
//  Created by Renat Kurbanov on 02.06.2026.
//

#if os(iOS)
import UIKit
import WebKit

@MainActor
class ApphudWebController: NSObject, WKNavigationDelegate {

    private static let timeoutNanoseconds: UInt64 = 10_000_000_000
    private static let readinessRetryDelayNanoseconds: UInt64 = 100_000_000
    private static let maxReadinessRetryAttempts = 3

    private var callback: ((String?) -> Void)?
    private var webView: WKWebView?
    private var timeoutTask: Task<Void, Never>?
    private var readinessRetryTask: Task<Void, Never>?
    private var didComplete = false

    func present(callback: @escaping (String?) -> Void) {
        self.callback = callback
        attemptPresent(readinessAttempt: 0)
    }

    private func attemptPresent(readinessAttempt: Int) {
        guard #available(iOS 15.0, *) else {
            complete(with: nil)
            return
        }

        guard let visibleController = apphudVisibleViewController() else {
            guard scheduleReadinessRetryIfNeeded(after: readinessAttempt) else {
                apphudLog("ApphudWebController skipped: visible controller not found after retries")
                complete(with: nil)
                return
            }
            return
        }

        guard canPresentWebView(on: visibleController) else {
            guard scheduleReadinessRetryIfNeeded(after: readinessAttempt) else {
                apphudLog("ApphudWebController skipped: visible controller is not ready after retries")
                complete(with: nil)
                return
            }
            return
        }

        readinessRetryTask?.cancel()
        readinessRetryTask = nil

        let urlString = "\(ApphudHttpClient.shared.connectDomainUrl)?api_key=\(ApphudHttpClient.shared.apiKey)&device_id=\(ApphudInternal.shared.currentDeviceID)&host=\(ApphudHttpClient.shared.host)"
        guard let url = URL(string: urlString) else {
            complete(with: nil)
            return
        }

        let config = WKWebViewConfiguration()
        let webView = WKWebView(frame: CGRect(x: 0, y: 0, width: 1, height: 1), configuration: config)
        webView.isHidden = true
        webView.alpha = 0
        webView.isUserInteractionEnabled = false
        webView.navigationDelegate = self

        visibleController.view.addSubview(webView)
        self.webView = webView

        startTimeout()
        webView.load(URLRequest(url: url))

        apphudLog("ApphudWebController started loading url \(url.absoluteString)")
    }

    private func scheduleReadinessRetryIfNeeded(after attempt: Int) -> Bool {
        guard attempt < Self.maxReadinessRetryAttempts else {
            return false
        }

        let nextAttempt = attempt + 1
        apphudLog("ApphudWebController retrying presentation (\(nextAttempt)/\(Self.maxReadinessRetryAttempts))")

        readinessRetryTask?.cancel()
        readinessRetryTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.readinessRetryDelayNanoseconds)
            guard let self, !Task.isCancelled, !self.didComplete else { return }
            self.attemptPresent(readinessAttempt: nextAttempt)
        }

        return true
    }

    private func canPresentWebView(on visibleController: UIViewController) -> Bool {
        guard UIApplication.shared.applicationState == .active else {
            return false
        }

        guard visibleController.isViewLoaded,
              let visibleView = visibleController.viewIfLoaded,
              visibleView.window != nil else {
            return false
        }

        if #available(iOS 13.0, *) {
            return visibleView.window?.windowScene?.activationState == .foregroundActive
        } else {
            return true
        }
    }

    private func startTimeout() {
        timeoutTask?.cancel()
        timeoutTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: Self.timeoutNanoseconds)
            guard let self, !Task.isCancelled else { return }
            apphudLog("ApphudWebController timed out")
            self.complete(with: nil)
        }
    }

    private func fetchVisitorId() {
        guard !didComplete, let webView else { return }

        
        apphudLog("ApphudWebController getVisitorId called")
        webView.callAsyncJavaScript("return await getConnectId();", in: nil, in: .page) { [weak self] result in
            Task { @MainActor in
                apphudLog("ApphudWebController getVisitorId callback invoked: \(result)")
                
                
                guard let self, !self.didComplete else { return }

                switch result {
                case .success(let value):
                    if let visitorId = value as? String, !visitorId.isEmpty {
                        apphudLog("ApphudWebController getVisitorId returned: \(visitorId)")
                        self.complete(with: visitorId)
                    } else {
                        apphudLog("ApphudWebController getVisitorId returned invalid value")
                        self.complete(with: nil)
                    }
                case .failure(let error):
                    apphudLog("ApphudWebController getVisitorId failed: \(error.localizedDescription)")
                    self.complete(with: nil)
                }
            }
        }
    }

    func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard !didComplete else { return }
        apphudLog("ApphudWebController did finish loading")
        fetchVisitorId()
    }

    func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
        apphudLog("ApphudWebController did fail: \(error.localizedDescription)")
        complete(with: nil)
    }

    func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
        apphudLog("ApphudWebController did fail provisional navigation: \(error.localizedDescription)")
        complete(with: nil)
    }

    func webViewWebContentProcessDidTerminate(_ webView: WKWebView) {
        apphudLog("ApphudWebController web content process terminated")
        complete(with: nil)
    }

    private func complete(with result: String?) {
        guard !didComplete, let callback else { return }
        didComplete = true
        self.callback = nil

        timeoutTask?.cancel()
        timeoutTask = nil
        readinessRetryTask?.cancel()
        readinessRetryTask = nil

        webView?.stopLoading()
        webView?.navigationDelegate = nil
        webView?.removeFromSuperview()
        webView = nil

        ApphudInternal.shared.webController = nil
        callback(result)
    }
}
#else
@MainActor
class ApphudWebController {

    func present(callback: @escaping (String?) -> Void) {
        ApphudInternal.shared.webController = nil
        callback(nil)
    }
}
#endif
