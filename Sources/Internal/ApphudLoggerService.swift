//
//  ApphudLoggerService.swift
//  ApphudSDK
//
//  Created by Valery on 27.05.2021.
//

import Foundation
import StoreKit

class ApphudLoggerService {

    static var lastUserUpdatedAt: Date? {
        get {
            return UserDefaults.standard.object(forKey: "lastUserUpdatedAt") as? Date
        }
        set {
            return UserDefaults.standard.set(Date(), forKey: "lastUserUpdatedAt")
        }
    }

    enum DurationLog: String {
        case customers = "/v1/customers"
        case products = "/v2/products"
        case paywallConfigs = "/v2/paywall_configs"
        case subscriptions = "/v1/subscriptions"
    }
    
    internal var customerLoadTime: Double = 0
    internal var errorCode: Int? = nil
    internal var customerRegisterAttempts: Int = 0
    internal var didSend = false
    internal static let shared = ApphudLoggerService()
    private var durationLogs: [[String: AnyHashable]] = []
    private var durationLogsTimer = Timer()

    // MARK: - Paywalls logs

    internal func paywallShown(paywall: ApphudPaywall) {
        ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_shown", "properties": ["paywall_id": paywall.id, "placement_id": paywall.placementId, "variation_identifier": paywall.variationIdentifier, "experiment_id": paywall.experimentId].compactMapValues { $0 } ])
    }

    internal func paywallClosed(paywallId: String?, placementId: String?) {
        ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_closed", "properties": ["paywall_id": paywallId, "placement_id": placementId].compactMapValues { $0 }])
    }

    internal func paywallCheckoutInitiated(apphudProduct: ApphudProduct?, productId: String?) {
        ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_checkout_initiated", "properties": ["paywall_id":  apphudProduct?.paywallId, "placement_id": apphudProduct?.placementId, "product_id": productId, "variation_identifier": apphudProduct?.variationIdentifier, "experiment_id": apphudProduct?.experimentId].compactMapValues { $0 } ])
    }

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    internal func paywallPaymentCancelled(paywallId: String?, placementId: String?, product: Product) {
        paywallPaymentError(paywallId: paywallId, placementId: placementId, productId: product.id, error: "userCancelled")
    }

    internal func paywallPaymentError(paywallId: String?, placementId: String?, productId: String?, error: String) {

        if error == "userCancelled" || error == "paymentCancelled" {
            ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_payment_cancelled", "properties": ["paywall_id": paywallId, "placement_id": placementId, "product_id": productId ?? ""].compactMapValues { $0 }])
        } else {
            ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_payment_error", "properties": ["paywall_id": paywallId, "placement_id": placementId, "product_id": productId, "error_message": error].compactMapValues { $0 }])
        }
    }

    // MARK: - Duration Logs

    internal func add(key: DurationLog, value: Double, retryLog: ApphudRetryLog) {
        DispatchQueue.main.async {
            if self.durationLogs.count != 0 {
                self.durationLogsTimer.invalidate()
            }
            self.durationLogsTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(self.durationTimerAction), userInfo: nil, repeats: false)

            var params: [String: AnyHashable] = ["endpoint": key.rawValue, "duration": Double(round(100 * value) / 100)]

            params["retries"] = retryLog.count
            params["error_code"] = retryLog.errorCode

            self.durationLogs.append(params)
            
            if (key == .customers) {
                self.customerLoadTime = Double(round(100 * value) / 100)
                self.errorCode = retryLog.errorCode
                self.customerRegisterAttempts = retryLog.count
            }
        }
    }
    
    @objc private func durationTimerAction() {
        let sdkLaunchedAt = ApphudInternal.shared.initDate.timeIntervalSince1970 * 1000.0
        let productsCount = ApphudStoreKitWrapper.shared.products.count
        let customerErrorMessage = (errorCode != nil) ? String(errorCode!) : nil
        let paywallsLoadTime = ApphudInternal.shared.paywallsLoadTime
        let productsLoadTime = ApphudStoreKitWrapper.shared.productsLoadTime
        var metrics: [String: AnyHashable] = ["launched_at": Int64(sdkLaunchedAt),
                                              "total_load_time": Double(round(100 * paywallsLoadTime) / 100)*1000.0,
                                              "user_load_time": Double(round(100 * customerLoadTime) / 100)*1000.0,
                                              "products_load_time": Double(round(100 * productsLoadTime) / 100) * 1000.0,
                       "products_count": productsCount
        ]
        
        if let errorString = ApphudStoreKitWrapper.shared.latestError()?.localizedDescription {
            metrics["storekit_error"] = errorString
        }
        if let message = customerErrorMessage {
            metrics["error_message"] = message
        }
        if customerRegisterAttempts > 1 {
            metrics["failed_attempts"] = String(customerRegisterAttempts)
        }
        
        if customerRegisterAttempts <= 1 && productsCount > 0 && customerErrorMessage == nil {
            metrics["result"] = "no_issues"
        } else {
            metrics["result"] = "has_issues"
        }
        
        apphudLog("SDK Performance Metrics: \n\(metrics)")
        
        if ((ApphudInternal.shared.isFreshInstall || ApphudInternal.shared.isRedownload) &&
            customerLoadTime > 0 && productsLoadTime > 0 && paywallsLoadTime > 0 && !didSend) {
            didSend = true
            ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_products_loaded", "properties": metrics.compactMapValues { $0 }])
        }
    }
}
