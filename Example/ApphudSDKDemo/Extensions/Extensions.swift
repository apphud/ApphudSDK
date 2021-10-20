//
//  Extensions.swift
//  Apphud, Inc
//
//  Created by ren6 on 04/09/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import Foundation
import UIKit
import StoreKit
import ApphudSDK

extension SKProduct {
        
    func getProductDuration() -> String? {
        var unit = ""
        switch self.subscriptionPeriod?.unit {
        case .day:
            unit = "\(subscriptionPeriod!.numberOfUnits) days"
        case .week:
            unit = "weekly"
        case .month:
            unit = "monthly"
        case .year:
            unit = "annually"
        default:
            unit = "lifetime"
        }
        return unit
    }
    
    func getProductPrice() -> String? {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = priceLocale
        numberFormatter.currencyCode = priceLocale.currencyCode
        numberFormatter.currencySymbol = priceLocale.currencySymbol
        let priceString = numberFormatter.string(from: price)
        return priceString ?? ""
    }
    
    func getFullSubscriptionInfoString() -> String? {

        guard subscriptionPeriod != nil else {return nil}

        let unit = unitStringFrom(unitValue: subscriptionPeriod!.unit)

        let priceString = localizedPriceFrom(price: price)

        var string = localizedTitle + ": \(priceString)" + ", \(subscriptionPeriod!.numberOfUnits) " + "\(unit)"

        if let intro = introductoryPrice {
            string = "\(string)\n\nHas following introductory offer:\n\(discountDescription(discount: intro))"
        }

        if #available(iOS 12.2, *) {
            if discounts.count > 0 {
                string = "\(string)\n\nHas following promotional offers:\n"

                for discount in discounts {
                    string = "\(string)PROMO \(discount.identifier ?? ""): \(discountDescription(discount: discount))\n"
                }
            }
        }

        return string
    }

    private func unitStringFrom(unitValue: SKProduct.PeriodUnit) -> String {
        var unit = ""
        switch unitValue {
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

    private func localizedPriceFrom(price: NSDecimalNumber) -> String {
        let numberFormatter = NumberFormatter()
        numberFormatter.numberStyle = .currency
        numberFormatter.locale = priceLocale
        numberFormatter.currencyCode = priceLocale.currencyCode
        numberFormatter.currencySymbol = priceLocale.currencySymbol
        let priceString = numberFormatter.string(from: price)
        return priceString ?? ""
    }

    private func discountDescription(discount: SKProductDiscount) -> String {

        let periodsCount = discount.numberOfPeriods

        let unit = unitStringFrom(unitValue: discount.subscriptionPeriod.unit)

        let unitCount = discount.subscriptionPeriod.numberOfUnits

        let priceString = localizedPriceFrom(price: discount.price)

        var string = ""
        if discount.paymentMode == .payAsYouGo {
            string = "PAY AS YOU GO: \(priceString) every \(unitCount) \(unit) and pay it \(periodsCount) times"
        } else if discount.paymentMode == .payUpFront {
            string = "INTRO PAY UP FRONT: \(priceString) per \(unitCount) \(unit) for  \(periodsCount) times"
        } else if discount.paymentMode == .freeTrial {
            string = "FREE TRIAL: \(priceString) per \(unitCount) \(unit) for  \(periodsCount) times"
        }
        return string
    }
}

struct LoaderDialog {
    static var alert = UIAlertController()
    static var progressView = UIProgressView()
    static var progressPoint : Float = 0 {
        didSet {
            if (progressPoint == 1) {
                LoaderDialog.alert.dismiss(animated: true, completion: nil)
            }
        }
    }
}

extension UIViewController {
    func showLoader() {
        LoaderDialog.alert = UIAlertController(title: nil, message: "Connect to Apple...", preferredStyle: .alert)
        
        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = UIActivityIndicatorView.Style.white
        loadingIndicator.startAnimating()
        
        LoaderDialog.alert.view.addSubview(loadingIndicator)
        present(LoaderDialog.alert, animated: true, completion: nil)
    }
    
    func hideLoader() {
        LoaderDialog.alert.dismiss(animated: true, completion: nil)
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
