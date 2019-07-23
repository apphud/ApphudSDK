//
//  ApphudExtensions.swift
//  subscriptionstest
//
//  Created by Renat on 26/06/2019.
//  Copyright © 2019 apphud. All rights reserved.
//

import Foundation
import StoreKit

extension SKProduct {
    
    func submittableParameters() -> [String : Any] {
        
        var params : [String : Any] = [
                        "product_id" : productIdentifier,
                        "price" : price.floatValue
        ]

        if let countryCode = priceLocale.regionCode {
            params["country_code"] = countryCode
        }
        if let currencyCode = priceLocale.currencyCode {
            params["currency_code"] = currencyCode
        }
        
        if #available(iOS 11.2, *) {
            if let introData = introParameters() {
                params.merge(introData, uniquingKeysWith: {$1})
            }
            if subscriptionPeriod != nil {
                let units_count = subscriptionPeriod!.numberOfUnits
                params["unit"] = unitStringFrom(periodUnit: subscriptionPeriod!.unit)
                params["units_count"] = units_count                
            }
        }
        
        return params
    }
    
    private func unitStringFrom(periodUnit : SKProduct.PeriodUnit) -> String {
        var unit = ""
        switch periodUnit {
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
    
    private func introParameters() -> [String : Any]? {
        
        if let intro = introductoryPrice {
            let intro_periods_count = intro.numberOfPeriods
            
            let intro_unit_count = intro.subscriptionPeriod.numberOfUnits
            
            var mode :String?
            switch intro.paymentMode {
            case .payUpFront:
                mode = "pay_up_front"
            case .payAsYouGo:
                mode = "pay_as_you_go"
            case .freeTrial:
                break
            //                mode = "free_trial"
            default:
                break
            }
            
            let intro_unit = unitStringFrom(periodUnit: intro.subscriptionPeriod.unit)
            
            if let aMode = mode{
                return ["intro_unit" : intro_unit, "intro_units_count" : intro_unit_count, "intro_periods_count" : intro_periods_count, "intro_mode" : aMode, "intro_price" : intro.price.floatValue]                
            }
        }
        
        return nil
    }
}
