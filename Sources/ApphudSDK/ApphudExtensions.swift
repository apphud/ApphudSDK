//
//  ApphudExtensions.swift
// Apphud
//
//  Created by ren6 on 26/06/2019.
//  Copyright © 2019 Softeam Inc. All rights reserved.
//

import Foundation
import StoreKit
import AdSupport

typealias ApphudVoidCallback = (() -> Void)

internal func apphudLog(_ text : String, forceDisplay: Bool = false) {
    if ApphudUtils.shared.isLoggingEnabled || forceDisplay {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        let time = formatter.string(from: Date())
        print("[\(time)] [Apphud] \(text)")
    }
}

enum ApphudError: LocalizedError {
    case error(message: String)
    var errorDescription: String? {
        switch self {
        case let .error(message):
            return message
        }
    }
}

internal func apphudVisibleViewController() -> UIViewController? {
    var currentVC = UIApplication.shared.keyWindow?.rootViewController
    while let presentedVC = currentVC?.presentedViewController {
        currentVC = presentedVC
    }
    return currentVC
}

internal func apphudDidMigrate(){
    UserDefaults.standard.set(true, forKey: "ApphudSubscriptionsMigrated")
    UserDefaults.standard.synchronize()    
}

internal func apphudShouldMigrate() -> Bool {
    return !UserDefaults.standard.bool(forKey: "ApphudSubscriptionsMigrated")
}

internal func toUserDefaultsCache(dictionary: [String : String], key: String){
    UserDefaults.standard.set(dictionary, forKey: key)
    UserDefaults.standard.synchronize()
}

internal func fromUserDefaultsCache(key: String) -> [String : String]? {
    return UserDefaults.standard.object(forKey: key) as? [String : String]
}

internal func currentDeviceParameters() -> [String : String]{
    
    let family : String
    if UIDevice.current.userInterfaceIdiom == .phone {
        family = "iPhone"
    } else {
        family = "iPad"
    }    
    let app_version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""
    
    var params : [String : String] = ["locale" : Locale.current.identifier,
                                      "time_zone" : TimeZone.current.identifier,
                                      "device_type" : UIDevice.current.apphudModelName, 
                                      "device_family" : family, 
                                      "platform" : "iOS", 
                                      "app_version" : app_version, 
                                      "start_app_version" : app_version, 
                                      "sdk_version" : sdk_version, 
                                      "os_version" : UIDevice.current.systemVersion,
    ]
    
    if let regionCode = Locale.current.regionCode {
        params["country_iso_code"] = regionCode.uppercased()
    }
    
    if let idfv = UIDevice.current.identifierForVendor?.uuidString {
        params["idfv"] = idfv
    }
    
    if !ApphudUtils.shared.optOutOfIDFACollection, let idfa = identifierForAdvertising(){
        params["idfa"] = idfa
    }
    
    return params
}

internal func identifierForAdvertising() -> String? {
    // Check whether advertising tracking is enabled
    guard ASIdentifierManager.shared().isAdvertisingTrackingEnabled else {
        return nil
    }

    // Get and return IDFA
    return ASIdentifierManager.shared().advertisingIdentifier.uuidString
}

extension UIDevice {
    var apphudModelName: String {
        var systemInfo = utsname()
        uname(&systemInfo)
        let machineMirror = Mirror(reflecting: systemInfo.machine)
        let identifier = machineMirror.children.reduce("") { identifier, element in
            guard let value = element.value as? Int8, value != 0 else { return identifier }
            return identifier + String(UnicodeScalar(UInt8(value)))
        }
        return identifier
    }
}


internal func receiptDataString() -> String? {
    guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
        return nil
    }
    var receiptData: Data? = nil
    do {
        receiptData = try Data(contentsOf: appStoreReceiptURL)
    }
    catch {}
    
    let string = receiptData?.base64EncodedString()
    return string
}

@available(iOS 11.2, *)
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
        
        if let introData = introParameters() {
            params.merge(introData, uniquingKeysWith: {$1})
        }
        
        if subscriptionPeriod != nil && subscriptionPeriod!.numberOfUnits > 0 {
            let units_count = subscriptionPeriod!.numberOfUnits
            params["unit"] = unitStringFrom(periodUnit: subscriptionPeriod!.unit)
            params["units_count"] = units_count
        }
        
        if #available(iOS 12.2, *) {
            var discount_params = [[String : Any]]()
            for discount in discounts {
                let promo_params = promoParameters(discount: discount)
                discount_params.append(promo_params)
            }
            if discount_params.count > 0 {
                params["promo_offers"] = discount_params
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
    
    @available(iOS 12.2, *)
    private func promoParameters(discount : SKProductDiscount) -> [String : Any] {
        
        let periods_count = discount.numberOfPeriods
        
        let unit_count = discount.subscriptionPeriod.numberOfUnits
        
        var mode :String = ""
        switch discount.paymentMode {
        case .payUpFront:
            mode = "pay_up_front"
        case .payAsYouGo:
            mode = "pay_as_you_go"
        case .freeTrial:
            mode = "trial"
        default:
            break
        }
        
        let unit = unitStringFrom(periodUnit: discount.subscriptionPeriod.unit)
        
        return ["unit" : unit, "units_count" : unit_count, "periods_count" : periods_count, "mode" : mode, "price" : discount.price.floatValue, "offer_id" : discount.identifier ?? ""]                
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
                mode = "trial"
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
    
    
    //MARK:- Screen extension methods
    
    func regularUnitString() -> String {
        
        guard let subscriptionPeriod = subscriptionPeriod else {
            return ""
        }
        let unit = unitStringFrom(periodUnit: subscriptionPeriod.unit) 
        let unit_count = subscriptionPeriod.numberOfUnits
        
        if unit_count > 1 {
            return "\(unit_count) \(unit)s" 
        } else {
            return unit
        }
    }
    
    func discountDurationString(discount: SKProductDiscount) -> String{
        let periods_count = discount.numberOfPeriods
        let unit = unitStringFrom(periodUnit: discount.subscriptionPeriod.unit) 
        let unit_count = discount.subscriptionPeriod.numberOfUnits        
        let totalUnits = periods_count * unit_count
        
        if totalUnits > 1 {
            return "\(totalUnits) \(unit)s" 
        } else {
            return unit
        }
    }
    
    func discountUnitString(discount: SKProductDiscount) -> String{
        let unit = unitStringFrom(periodUnit: discount.subscriptionPeriod.unit) 
        let unit_count = discount.subscriptionPeriod.numberOfUnits
        
        if unit_count > 1 {
            return "\(unit_count) \(unit)s"
        } else {
            return unit
        }
    }
    
    func localizedPrice() -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = priceLocale
        let priceString = numberFormatter.string(from: price)
        return priceString ?? ""
    }
    
    func localizedDiscountPrice(discount: SKProductDiscount) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = priceLocale
        let priceString = numberFormatter.string(from: discount.price)
        return priceString ?? ""
    }
}
