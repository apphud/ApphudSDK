//
//  ApphudExtensions.swift
//  Apphud, Inc
//
//  Created by ren6 on 26/06/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

#if os(watchOS)
import WatchKit
#endif
import Foundation
import StoreKit

typealias ApphudVoidCallback = (() -> Void)
typealias ApphudErrorCallback = ((Error?) -> Void)

#if os(iOS)
internal func apphudVisibleViewController() -> UIViewController? {

    let keyWindow = UIApplication.shared.windows.filter {$0.isKeyWindow}.first

    var currentVC = keyWindow?.rootViewController
    while let presentedVC = currentVC?.presentedViewController {
        currentVC = presentedVC
    }
    return currentVC
}
#endif

extension Date {
    internal var apphudIsoString: String {
        String.apphudIsoDateFormatter.string(from: self)
    }
}

extension String {
    /// Helper method to parse date string into Date object
    internal var apphudIsoDate: Date? {
        let date = Self.apphudIsoDateFormatter.date(from: self)
        if date != nil { return date }

        // fallback
        return apphudStandardIsoDate
    }

    internal var appleReceiptDate: Date? {
        if let date = DateFormatter.appleReceipt.date(from: self) {
            return date
        } else {
            // for local storekit receipts
            return apphudStandardIsoDate
        }
    }

    internal var apphudStandardIsoDate: Date? {
        Self.standardIsoDateFormatter.date(from: self)
    }

    internal static let apphudIsoDateFormatter: ISO8601DateFormatter = {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [.withFractionalSeconds,
                                   .withInternetDateTime,
                                   .withColonSeparatorInTimeZone,
                                   .withColonSeparatorInTime]
        return formatter
    }()

    private static let standardIsoDateFormatter = ISO8601DateFormatter()
}

private extension DateFormatter {
    static let appleReceipt: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd HH:mm:ss VV"
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        return formatter
    }()
}

internal func apphudIsSandbox() -> Bool {
    if apphudIsSimulator() {
        return true
    } else {
        if let url = Bundle.main.appStoreReceiptURL, url.lastPathComponent == "sandboxReceipt" {
            return true
        } else {
            return false
        }
    }
}

private func apphudIsSimulator() -> Bool {
    #if targetEnvironment(simulator)
        return true
    #else
        return false
    #endif
}

internal func apphudDidMigrate() {
    UserDefaults.standard.set(true, forKey: "ApphudSubscriptionsMigrated")
}

internal func apphudShouldMigrate() -> Bool {
    return !UserDefaults.standard.bool(forKey: "ApphudSubscriptionsMigrated")
}

internal func apphudDataClearCache(key: String) {
    if var url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
        url.appendPathComponent(key)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
    }
}

internal func apphudDataToCache(data: Data, key: String) {
    if var url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
        url.appendPathComponent(key)
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        try? data.write(to: url)
    }
}

internal func apphudDataFromCache(key: String, cacheTimeout: TimeInterval) -> (objectsData: Data?, expired: Bool) {
    if var url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first {
        url.appendPathComponent(key)

        if FileManager.default.fileExists(atPath: url.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let creationDate = attrs[.creationDate] as? Date,
           let data = try? Data(contentsOf: url) {
            return (data, (Date().timeIntervalSince(creationDate) > cacheTimeout))
        }
    }
    return (nil, true)
}

internal func apphudToUserDefaultsCache(dictionary: [String: String], key: String) {
    UserDefaults.standard.set(dictionary, forKey: key)
}

internal func apphudFromUserDefaultsCache(key: String) -> [String: String]? {
    return UserDefaults.standard.object(forKey: key) as? [String: String]
}

internal func apphudPerformOnMainThread(callback: @escaping () -> Void) {
    if Thread.isMainThread {
        callback()
    } else {
        DispatchQueue.main.async {
            callback()
        }
    }
}

#if os(macOS)
internal func apphudCurrentDeviceMacParameters() -> [String: String] {
    let app_version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""

    var params: [String: String] = ["locale": Locale.current.identifier,
                                      "time_zone": TimeZone.current.identifier,
                                      "device_type": "Mac",
                                      "device_family": "Mac",
                                      "platform": "macOS",
                                      "app_version": app_version,
                                      "start_app_version": app_version,
                                      "sdk_version": ApphudHttpClient.shared.sdkVersion,
                                    "os_version": "\(ProcessInfo.processInfo.operatingSystemVersion.majorVersion).\(ProcessInfo.processInfo.operatingSystemVersion.minorVersion)"
    ]

    if let regionCode = Locale.current.regionCode {
        params["country_iso_code"] = regionCode.uppercased()
    }

    if !ApphudUtils.shared.optOutOfTracking, let idfa = apphudIdentifierForAdvertising() {
        params["idfa"] = idfa
    }

    return params
}

#elseif os(watchOS)
internal func apphudCurrentDeviceWatchParameters() -> [String: String] {

    let family: String = "Watch"
    let app_version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""

    var params: [String: String] = [    "locale": Locale.current.identifier,
                                        "time_zone": TimeZone.current.identifier,
                                        "device_type": ApphudUtils.shared.optOutOfTracking ? "Restricted" : WKInterfaceDevice.current().model,
                                        "device_family": family,
                                        "platform": "iOS",
                                        "app_version": app_version,
                                        "start_app_version": app_version,
                                        "sdk_version": ApphudHttpClient.shared.sdkVersion,
                                        "os_version": WKInterfaceDevice.current().systemVersion
    ]

    if let regionCode = Locale.current.regionCode {
        params["country_iso_code"] = regionCode.uppercased()
    }

    if !ApphudUtils.shared.optOutOfTracking, let idfv = WKInterfaceDevice.current().identifierForVendor?.uuidString {
        params["idfv"] = idfv
    }

    if !ApphudUtils.shared.optOutOfTracking, let idfa = apphudIdentifierForAdvertising() {
        params["idfa"] = idfa
    }

    return params
}

#else
internal func apphudCurrentDeviceiOSParameters() -> [String: String] {

    var family = ""
    switch UIDevice.current.userInterfaceIdiom {
    case .phone:
        family = "iPhone"
    case .tv:
        family = "AppleTV"
    default:
        family = "iPad"
    }

    let app_version = (Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String) ?? ""

    var params: [String: String] = ["locale": Locale.current.identifier,
                                      "time_zone": TimeZone.current.identifier,
                                    "device_type": ApphudUtils.shared.optOutOfTracking ? "Restricted" : UIDevice.current.apphudModelName,
                                      "device_family": family,
                                      "platform": "iOS",
                                      "app_version": app_version,
                                      "start_app_version": app_version,
                                      "sdk_version": ApphudHttpClient.shared.sdkVersion,
                                      "os_version": UIDevice.current.systemVersion
    ]

    if let regionCode = Locale.current.regionCode {
        params["country_iso_code"] = regionCode.uppercased()
    }

    if !ApphudUtils.shared.optOutOfTracking, let idfv = UIDevice.current.identifierForVendor?.uuidString {
        params["idfv"] = idfv
    }

    if !ApphudUtils.shared.optOutOfTracking, let idfa = apphudIdentifierForAdvertising() {
        params["idfa"] = idfa
    }

    return params
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
#endif

internal func apphudIdentifierForAdvertising() -> String? {
    if let idfa = ApphudInternal.shared.advertisingIdentifier, idfa != "00000000-0000-0000-0000-000000000000" {
        return idfa
    }
    return nil
}

internal func apphudIsAppsFlyerSDKIntegrated() -> Bool {

    if true {
        let klass: AnyClass? = NSClassFromString("AppsFlyerLib")
        let managerClass = klass as AnyObject as? NSObjectProtocol

        let sel = NSSelectorFromString("shared")
        if managerClass?.responds(to: sel) ?? false {
            return true
        }
    }

    let klass: AnyClass? = NSClassFromString("AppsFlyerTracker")
    let managerClass = klass as AnyObject as? NSObjectProtocol

    let sel = NSSelectorFromString("sharedTracker")
    if managerClass?.responds(to: sel) ?? false {
        return true
    }

    return false
}

internal func apphudGetAppsFlyerID() -> String? {

    if true {
        let klass: AnyClass? = NSClassFromString("AppsFlyerLib")
        let managerClass = klass as AnyObject as? NSObjectProtocol

        let sel = NSSelectorFromString("shared")
        if managerClass?.responds(to: sel) ?? false {
            let value = managerClass?.perform(sel)
            if let tracker = value?.takeUnretainedValue() as? NSObject {
                let selID = NSSelectorFromString("getAppsFlyerUID")
                if tracker.responds(to: selID) {
                    let value = tracker.perform(selID)
                    if let string = value?.takeUnretainedValue() as? String, string.count > 0 {
                        return string
                    }
                }
            }
        }
    }

    let klass: AnyClass? = NSClassFromString("AppsFlyerTracker")
    let managerClass = klass as AnyObject as? NSObjectProtocol

    let sel = NSSelectorFromString("sharedTracker")
    if managerClass?.responds(to: sel) ?? false {
        let value = managerClass?.perform(sel)
        if let tracker = value?.takeUnretainedValue() as? NSObject {
            let selID = NSSelectorFromString("getAppsFlyerUID")
            if tracker.responds(to: selID) {
                let value = tracker.perform(selID)
                if let string = value?.takeUnretainedValue() as? String, string.count > 0 {
                    return string
                }
            }
        }
    }

    return nil
}

internal func apphudIsAdjustSDKIntegrated() -> Bool {

    let klass: AnyClass? = NSClassFromString("Adjust")
    let managerClass = klass as AnyObject as? NSObjectProtocol

    let sel = NSSelectorFromString("adid")
    if managerClass?.responds(to: sel) ?? false {
        return true
    }

    return false
}

internal func apphudGetAdjustID() -> String? {

    let klass: AnyClass? = NSClassFromString("Adjust")
    let managerClass = klass as AnyObject as? NSObjectProtocol

    let sel = NSSelectorFromString("adid")
    if managerClass?.responds(to: sel) ?? false {
        let value = managerClass?.perform(sel)
        if let string = value?.takeUnretainedValue() as? String, string.count > 0 {
            return string
        }
    }

    return nil
}

internal func apphudNeedsToCollectFBAnonID() -> Bool {
    true
}

internal func apphudIsFBSDKIntegrated() -> Bool {
    return NSClassFromString("FBSDKAppEvents") != nil || NSClassFromString("FBSDKBasicUtility") != nil
}

internal func apphudGetFBExtInfo() -> String? {

    let klass: AnyClass? = NSClassFromString("FBSDKAppEventsDeviceInfo")
    let managerClass = klass as AnyObject as? NSObjectProtocol

    let sel = NSSelectorFromString("sharedDeviceInfo")
    if managerClass?.responds(to: sel) ?? false {
        let value = managerClass?.perform(sel)
        if let shared = value?.takeUnretainedValue() as? NSObject {
            let selInfo = NSSelectorFromString("encodedDeviceInfo")
            if shared.responds(to: selInfo) {
                let value = shared.perform(selInfo)
                if let encodedString = value?.takeUnretainedValue() as? String, encodedString.count > 0 {
                    return encodedString
                }
            }
        }
    }

    return nil
}

internal func apphudGetFBAnonID() -> String? {

    let klass: AnyClass? = NSClassFromString("FBSDKAppEvents")
    let managerClass = klass as AnyObject as? NSObjectProtocol

    let sel = NSSelectorFromString("anonymousID")
    if managerClass?.responds(to: sel) ?? false {
        let value = managerClass?.perform(sel)
        if let string = value?.takeUnretainedValue() as? String, string.count > 0 {
            return string
        }
    }

    let klassOld: AnyClass? = NSClassFromString("FBSDKBasicUtility")
    let managerClassOld = klassOld as AnyObject as? NSObjectProtocol

    let selOld = NSSelectorFromString("anonymousID")
    if managerClassOld?.responds(to: selOld) ?? false {
        let value = managerClassOld?.perform(selOld)
        if let string = value?.takeUnretainedValue() as? String, string.count > 0 {
            return string
        }
    }

    return nil
}

internal func apphudReceiptDataString() -> String? {
    guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
        return nil
    }
    var receiptData: Data?
    do {
        receiptData = try Data(contentsOf: appStoreReceiptURL, options: .alwaysMapped)
    } catch {}

    let string = receiptData?.base64EncodedString()
    return string
}

@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
extension Product {
    var adamId: String? {
        if let dict = try? JSONSerialization.jsonObject(with: jsonRepresentation) as? [String: Any], let id = dict["id"] as? String {
            return id
        }
        return nil
    }
}

extension SKProduct {

    var apphudIsPaidIntro: Bool {
        introductoryPrice != nil && introductoryPrice!.price.doubleValue > 0
    }

    var apphudIsTrial: Bool {
        introductoryPrice != nil && introductoryPrice?.paymentMode == SKProductDiscount.PaymentMode.freeTrial
    }

    func apphudSubmittableParameters(_ purchased: Bool = false) -> [String: Any] {
        var params: [String: Any] = [
            "product_id": productIdentifier,
            "price": price.floatValue
        ]

        if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
            if let productStruct = ApphudAsyncStoreKit.shared.products.first(where: { $0.id == productIdentifier }), let adamID = productStruct.adamId {
                params["adam_id"] = adamID
            }
        } else {
            // Fallback on earlier versions
        }

        if let countryCode = priceLocale.regionCode {
            params["country_code"] = countryCode
        }

        if let currencyCode = priceLocale.currencyCode {
            params["currency_code"] = currencyCode
        }

        if let introData = apphudIntroParameters() {
            params.merge(introData, uniquingKeysWith: {$1})
        }

        if let value = ApphudStoreKitWrapper.shared.purchasingValue, value.productId == productIdentifier, purchased == true {
            params["custom_purchase_value"] = value.value
        }

        if subscriptionPeriod != nil && subscriptionPeriod!.numberOfUnits > 0 {
            let units_count = subscriptionPeriod!.numberOfUnits
            params["unit"] = apphudUnitStringFrom(periodUnit: subscriptionPeriod!.unit)
            params["units_count"] = units_count
        }

        var discount_params = [[String: Any]]()
        for discount in discounts {
            let promo_params = apphudPromoParameters(discount: discount)
            discount_params.append(promo_params)
        }
        if discount_params.count > 0 {
            params["promo_offers"] = discount_params
        }

        return params
    }

    private func apphudUnitStringFrom(periodUnit: SKProduct.PeriodUnit) -> String {
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

    private func apphudPromoParameters(discount: SKProductDiscount) -> [String: Any] {

        let periods_count = discount.numberOfPeriods

        let unit_count = discount.subscriptionPeriod.numberOfUnits

        var mode: String = ""
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

        let unit = apphudUnitStringFrom(periodUnit: discount.subscriptionPeriod.unit)

        return ["unit": unit, "units_count": unit_count, "periods_count": periods_count, "mode": mode, "price": discount.price.floatValue, "offer_id": discount.identifier ?? ""]
    }

    func apphudPromoIdentifiers() -> [String] {
        var array = [String]()
        for discount in discounts {
            if let id = discount.identifier {
                array.append(id)
            }
        }
        return array
    }

    private func apphudIntroParameters() -> [String: Any]? {

        if let intro = introductoryPrice {
            let intro_periods_count = intro.numberOfPeriods

            let intro_unit_count = intro.subscriptionPeriod.numberOfUnits

            var mode: String?
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

            let intro_unit = apphudUnitStringFrom(periodUnit: intro.subscriptionPeriod.unit)

            if let aMode = mode {
                return ["intro_unit": intro_unit, "intro_units_count": intro_unit_count, "intro_periods_count": intro_periods_count, "intro_mode": aMode, "intro_price": intro.price.floatValue]
            }
        }

        return nil
    }

    // MARK: - Screen extension methods

    func apphudRegularUnitString() -> String {

        guard let subscriptionPeriod = subscriptionPeriod else {
            return ""
        }
        let unit = apphudUnitStringFrom(periodUnit: subscriptionPeriod.unit)
        let unit_count = subscriptionPeriod.numberOfUnits

        if unit_count > 1 {
            return "\(unit_count) \(unit)s"
        } else {
            return unit
        }
    }

    func apphudDiscountDurationString(discount: SKProductDiscount) -> String {
        let periods_count = discount.numberOfPeriods
        let unit = apphudUnitStringFrom(periodUnit: discount.subscriptionPeriod.unit)
        let unit_count = discount.subscriptionPeriod.numberOfUnits
        let totalUnits = periods_count * unit_count

        if totalUnits > 1 {
            return "\(totalUnits) \(unit)s"
        } else {
            return unit
        }
    }

    func apphudDiscountUnitString(discount: SKProductDiscount) -> String {
        let unit = apphudUnitStringFrom(periodUnit: discount.subscriptionPeriod.unit)
        let unit_count = discount.subscriptionPeriod.numberOfUnits

        if unit_count > 1 {
            return "\(unit_count) \(unit)s"
        } else {
            return unit
        }
    }

    func apphudLocalizedPrice() -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = priceLocale
        let priceString = numberFormatter.string(from: price)
        return priceString ?? ""
    }

    func apphudLocalizedDiscountPrice(discount: SKProductDiscount) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = priceLocale
        let priceString = numberFormatter.string(from: discount.price)
        return priceString ?? ""
    }
}
