//
//  Extensions.swift
//  apphud
//
//  Created by Renat on 04/09/2019.
//  Copyright © 2019 softeam. All rights reserved.
//

import Foundation
import UIKit
import StoreKit

extension SKProduct {
    
    func unitStringFrom(un : SKProduct.PeriodUnit) -> String{
        var unit = ""
        switch un {
        case .day:
            unit = "day"
        case .week:
            unit = "week"
        case .month:
            unit = "month"
        case .year:
            unit = "year"
        default:
            break
        }
        return unit
    }
    
    func localizedPriceFrom(price : NSDecimalNumber) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = priceLocale
        let priceString = numberFormatter.string(from: price)
        return priceString ?? ""
    }
    
    func discountDescription(discount : SKProductDiscount) -> String {
        
        
        let periods_count = discount.numberOfPeriods
        
        let unit = unitStringFrom(un: discount.subscriptionPeriod.unit)
        
        let unit_count = discount.subscriptionPeriod.numberOfUnits
        
        let priceString = localizedPriceFrom(price: discount.price)
        
        var string = ""
        if discount.paymentMode == .payAsYouGo {
            string = "PAY AS YOU GO: \(priceString) every \(unit_count) \(unit) and pay it \(periods_count) times"
        } else if discount.paymentMode == .payUpFront {
            string = "INTRO PAY UP FRONT: \(priceString) per \(unit_count) \(unit) for  \(periods_count) times"   
        } else if discount.paymentMode == .freeTrial {
            string = "FREE TRIAL: \(priceString) per \(unit_count) \(unit) for  \(periods_count) times"  
        }
        return string
    }
    
    func fullSubscriptionInfoString() -> String?{
        
        guard subscriptionPeriod != nil else {return nil}
        
        let unit = unitStringFrom(un: subscriptionPeriod!.unit)
        
        let priceString = localizedPriceFrom(price: price)
        
        var string = localizedTitle + ": \(priceString)" + ", \(subscriptionPeriod!.numberOfUnits) " + "\(unit)"
        
        if let intro = introductoryPrice {
            string = "\(string)\n\nHas following introductory offer:\n\(discountDescription(discount: intro))"
        }
        
        if #available(iOS 12.2, *) {
            if discounts.count > 0 {
                string = "\(string)\n\nHas following promotional offers:\n"
                for (i, discount) in discounts.enumerated() {
                    string = "\(string)PROMO OFFER \(discount.identifier): \(discountDescription(discount: discount))\n"                    
                }
            }
        }
        
        return string
    }
}

extension ApphudSubscriptionStatus {
    /**
     This function can only be used in Swift
     */
    func toStringDuplicate() -> String {
        
        switch self {
        case .trial:
            return "trial"
        case .intro:
            return "intro"
        case .promo:
            return "promo"
        case .grace:
            return "grace"
        case .regular:
            return "regular"
        case .refunded:
            return "refunded"
        case .expired:
            return "expired"
        default:
            return ""
        }
    }
}
