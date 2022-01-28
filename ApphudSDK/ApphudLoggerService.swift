//
//  ApphudLoggerService.swift
//  ApphudSDK
//
//  Created by Валерий Левшин on 27.05.2021.
//

import Foundation
import StoreKit

@available(OSX 10.14.4, *)
class ApphudLoggerService {

    static var lastUserUpdatedAt: Date? {
        get {
            return UserDefaults.standard.object(forKey: "lastUserUpdatedAt") as? Date
        }
        set {
            return UserDefaults.standard.set(Date(), forKey: "lastUserUpdatedAt")
        }
    }

    enum durationLog {
        case customers
        case products
        case paywallConfigs
        case subscriptions

        func value() -> String {
            switch self {
            case .customers:
                return "/v1/customers"
            case .products:
                return "/v2/products"
            case .paywallConfigs:
                return "/v2/paywall_configs"
            case .subscriptions:
                return "/v1/subscriptions"
            }
        }
    }

    internal static let shared = ApphudLoggerService()
    private var durationLogs: [[String: AnyHashable]] = []
    private var durationLogsTimer = Timer()

    // MARK: - Paywalls logs

    internal func paywallShown(_ paywallId: String?) {
        ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_shown", "properties": ["paywall_id": paywallId ?? ""] ])
    }

    internal func paywallClosed(_ paywallId: String?) {
        ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_closed", "properties": ["paywall_id": paywallId ?? ""] ])
    }

    internal func paywallCheckoutInitiated(_ paywallId: String?, _ productId: String?) {
        ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_checkout_initiated", "properties": ["paywall_id": paywallId ?? "", "product_id": productId ?? ""] ])
    }

    internal func paywallPaymentCancelled(_ paywallId: String?, _ productId: String?, _ error: SKError) {
        if error.code == SKError.Code.paymentCancelled {
            ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_payment_cancelled", "properties": ["paywall_id": paywallId ?? "", "product_id": productId ?? ""] ])
        }
    }

    // MARK: - Duration Logs

    internal func addDurationEvent(_ key: String, _ value: Double) {
        if durationLogs.count != 0 {
            durationLogsTimer.invalidate()
        }
        durationLogsTimer = Timer.scheduledTimer(timeInterval: 5.0, target: self, selector: #selector(durationTimerAction), userInfo: nil, repeats: false)
        self.durationLogs.append(["path": key, "duration": Double(round(100 * value) / 100)])
    }

    @objc private func durationTimerAction() {
        self.sendLogEvents(durationLogs)
    }

    private func sendLogEvents(_ logs: [[String: AnyHashable]]) {
        self.durationLogs.removeAll()
        ApphudInternal.shared.trackDurationLogs(params: logs) {}
    }
}
