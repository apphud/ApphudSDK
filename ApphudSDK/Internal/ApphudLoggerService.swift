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

    internal static let shared = ApphudLoggerService()
    private var durationLogs: [[String: AnyHashable]] = []
    private var durationLogsTimer = Timer()

    // MARK: - Paywalls logs

    internal func paywallShown(paywallId: String?, placementId: String?) {
        ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_shown", "properties": ["paywall_id": paywallId, "placement_id": placementId].compactMapValues{ $0 } ])
    }

    internal func paywallClosed(paywallId: String?, placementId: String?) {
        ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_closed", "properties":  ["paywall_id": paywallId, "placement_id": placementId].compactMapValues{ $0 }])
    }

    internal func paywallCheckoutInitiated(paywallId: String?, placementId: String?, productId: String?) {
        ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_checkout_initiated", "properties": ["paywall_id": paywallId, "placement_id": placementId, "product_id": productId].compactMapValues{ $0 } ])
    }

    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    internal func paywallPaymentCancelled(paywallId: String?, placementId: String?, product: Product) {
        ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_payment_cancelled", "properties": ["paywall_id": paywallId, "placement_id": placementId, "product_id": product.id].compactMapValues{ $0 }])
    }

    internal func paywallPaymentCancelled(paywallId: String?, placementId: String?, productId: String?, _ error: SKError?) {

        guard let error = error else {return}

        if error.code == SKError.Code.paymentCancelled {
            ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_payment_cancelled", "properties": ["paywall_id": paywallId, "placement_id": placementId, "product_id": productId ?? ""].compactMapValues{ $0 }])
        } else {

            let underlying_error_code = (error as NSError?)?.apphudUnderlyingErrorCode ?? -1
            let underlying_error_description = (error as NSError?)?.apphudUnderlyingErrorDescription

            ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_payment_error", "properties": ["paywall_id": paywallId, "placement_id": placementId, "product_id": productId, "error_code": "\(error.code)", "underlying_error_code": "\(underlying_error_code)", "underlying_error_description": "\(underlying_error_description ?? "")"].compactMapValues{ $0 }])
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
        }
    }

    @objc private func durationTimerAction() {
        if ApphudStoreKitWrapper.shared.productsLoadTime > 0 {
            durationLogs.append(["endpoint": "skproducts", "duration": ApphudStoreKitWrapper.shared.productsLoadTime])
            ApphudStoreKitWrapper.shared.productsLoadTime = 0
        }
        if ApphudInternal.shared.paywallsLoadTime > 0 {
            durationLogs.append(["endpoint": "paywalls_total", "duration": ApphudInternal.shared.paywallsLoadTime])
            ApphudInternal.shared.paywallsLoadTime = 0
        }
        self.sendLogEvents(durationLogs)
    }

    private func sendLogEvents(_ logs: [[String: AnyHashable]]) {
        DispatchQueue.global().async {
            let data = try? JSONSerialization.data(withJSONObject: logs, options: [.prettyPrinted])
            let str = (data != nil ? String(data: data!, encoding: .utf8) : logs.description) ?? ""
            apphudLog("SDK Performance Metrics: \n\(str)")
            DispatchQueue.main.async {
                self.durationLogs.removeAll()
            }
        }
    }
}
