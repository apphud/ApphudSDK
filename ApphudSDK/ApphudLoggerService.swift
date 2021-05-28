//
//  ApphudLoggerService.swift
//  ApphudSDK
//
//  Created by Валерий Левшин on 27.05.2021.
//

import Foundation
import StoreKit

class ApphudLoggerService {
    
    class func paywallShown(_ paywallId: String?) {
        ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_shown", "properties":["paywall_id":paywallId ?? ""] ]) {}
    }
    
    class func paywallClosed(_ paywallId: String?) {
        ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_closed", "properties":["paywall_id":paywallId ?? ""] ]) {}
    }
    
    class func paywallCheckoutInitiated(_ paywallId: String?,_ productId:String?) {
        ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_checkout_initiated", "properties":["paywall_id":paywallId ?? "", "product_id":productId ?? ""] ]) {}
    }
    
    class func paywallPaymentError(_ paywallId: String?,_ productId:String?,_ error: SKError) {
        if error.code != SKError.Code.paymentCancelled {
            ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_payment_error", "properties":["paywall_id":paywallId ?? "", "product_id":productId ?? ""] ]) {}
        } else {
            ApphudInternal.shared.trackPaywallEvent(params: ["name": "paywall_payment_cancelled", "properties":["paywall_id":paywallId ?? "", "product_id":productId ?? ""] ]) {}
        }
    }
}