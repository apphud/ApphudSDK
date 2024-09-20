//
//  SKProduct+Extension.swift
//  ApphudSDKDemo
//
//  Created by Renat Kurbanov on 13.02.2023.
//  Copyright © 2023 Apphud. All rights reserved.
//

import Foundation
import StoreKit

//extension SKProduct {
//
//    /**
//     Returns product pricing terms in the following format:
//     "3 days free trial, then $1.99 / week' if free trial,
//     "Weekly Access – $1.99 / week" if no trial,
//     "Weekly Access – $1.99 / week" if no trial,
//     "Life Time Access – $19.99" if not a subscription
//     */
//
//    func pricingDescription() -> String {
//        if subscriptionPeriod != nil {
//            if introductoryPrice != nil {
//                return autoDescription() + ", " + autoPrice()
//            } else {
//                return autoDescription() + " – " + autoPrice()
//            }
//        } else {
//            return autoDescription() + " – " + autoPrice()
//        }
//    }
//
//    private func autoDescription() -> String {
//        if subscriptionPeriod != nil {
//            if introductoryPrice != nil {
//                return introductoryOnlyStringFull()
//            } else {
//                return periodDescriptionOnlyFull()
//            }
//        } else {
//            return periodDescriptionOnlyFull()
//        }
//    }
//
//    private func autoDescriptionShort() -> String {
//        if subscriptionPeriod != nil {
//            if introductoryPrice != nil {
//                return introductoryOnlyStringShort()
//            } else {
//                return periodDescriptionOnlyShort()
//            }
//        } else {
//            return periodDescriptionOnlyShort()
//        }
//    }
//
//    private func autoPrice() -> String {
//        if subscriptionPeriod != nil {
//            if introductoryPrice != nil {
//                return "then" + " " + priceWithPeriod()
//            } else {
//                return priceWithPeriod()
//            }
//        } else {
//            return priceValue(value: price)
//        }
//    }
//
//    private func withoutIntroductoryString() -> String {
//        "then" + " " + priceWithPeriod()
//    }
//
//    class func priceValue(value: NSDecimalNumber, locale: Locale) -> String {
//        let formatter = NumberFormatter()
//        formatter.numberStyle = .currency
//        formatter.locale = locale
//        formatter.currencySymbol = locale.currencySymbol
//        return formatter.string(from: value) ?? ""
//    }
//
//    func priceValue(value: NSDecimalNumber) -> String {
//        Self.priceValue(value: value, locale: priceLocale)
//    }
//
//    private func priceWithPeriod() -> String {
//        var period = periodName(from: subscriptionPeriod)
//        if period == "day" && subscriptionPeriod?.numberOfUnits ?? 0 == 7 {
//            period = "week"
//        }
//
//        return priceValue(value: price) + " / " + period
//    }
//
//    private func introductoryOnlyStringFull() -> String {
//        if isPaidIntro {
//            return paidIntroDescriptionFull()
//        } else {
//            return (introString() + " " + "free trial")
//        }
//    }
//
//    private func introductoryOnlyStringShort() -> String {
//        if isPaidIntro {
//            return periodDescriptionShort(periodUnit: introductoryPrice!.subscriptionPeriod.unit)
//        } else {
//            return (introString() + " " + "free")
//        }
//    }
//
//    private func introductoryPriceWithPeriod() -> String {
//        guard let intro = introductoryPrice else {return ""}
//        if isPaidIntro {
//            let period = periodName(from: intro.subscriptionPeriod)
//            return "\(priceValue(value: intro.price)) / \(period)"
//        } else {
//            return "free"
//        }
//    }
//
//    var isPaidIntro: Bool {
//        introductoryPrice != nil && introductoryPrice!.price.doubleValue > 0
//    }
//
//    private func introductoryPriceOnly() -> String {
//        guard let intro = introductoryPrice else {return ""}
//        if isPaidIntro {
//            return priceValue(value: intro.price)
//        } else {
//            return "free"
//        }
//    }
//
//    private func introString() -> String {
//        guard let intro = introductoryPrice else {return ""}
//
//        let introUnits = intro.subscriptionPeriod.numberOfUnits
//        let introUnitString = periodName(from: intro.subscriptionPeriod)
//        var introString = "\(introUnits)" + " " + introUnitString + (introUnits > 1 ? "s" : "")
//        if introUnits == 1 && introUnitString == "week" {
//            introString = "7 days"
//        }
//        return introString
//    }
//
//    private func introductoryPeriodOnly() -> String {
//        guard let intro = introductoryPrice else {return ""}
//        return periodName(from: intro.subscriptionPeriod)
//    }
//
//    private func paidIntroDescriptionFull() -> String {
//        guard let intro = introductoryPrice else {return ""}
//        switch intro.paymentMode {
//        case .payAsYouGo:
//            let periodDesc: String
//            if intro.numberOfPeriods == 1 {
//                periodDesc = "for the 1st \(periodName(from: intro.subscriptionPeriod))"
//            } else {
//                let localized: NSString = NSLocalizedString("for the first %@ %@s", comment: "") as NSString
//                periodDesc = NSString(format: localized, NSNumber(integerLiteral: intro.numberOfPeriods), periodName(from: intro.subscriptionPeriod)) as String
//            }
//            return "\(priceValue(value: intro.price)) \(periodDesc)"
//        case .payUpFront:
//            let periodDesc = "for the 1st \(periodName(from: intro.subscriptionPeriod))"
//            return "\(priceValue(value: intro.price)) \(periodDesc)"
//        default:
//            return ""
//        }
//    }
//
//    private func periodDescriptionOnlyFull() -> String {
//        if subscriptionPeriod != nil {
//            switch subscriptionPeriod!.unit {
//                case .week, .day:
//                    return "Weekly Access"
//                case .month:
//                    return "Monthly Access"
//                case .year:
//                    return "Yearly Access"
//                default:
//                    return ""
//            }
//        } else {
//            return "Life Time Access"
//        }
//    }
//
//    private func periodDescriptionOnlyShort() -> String {
//        if subscriptionPeriod != nil {
//            return periodDescriptionShort(periodUnit: subscriptionPeriod!.unit)
//        } else {
//            return "life time"
//        }
//    }
//
//    private func periodDescriptionShort(periodUnit: SKProduct.PeriodUnit) -> String {
//        switch periodUnit {
//            case .week, .day:
//                return "weekly"
//            case .month:
//                return "monthly"
//            case .year:
//                return "yearly"
//            default:
//                return ""
//        }
//    }
//
//    private func yearToMonthDivide() -> String {
//        let divided = price.dividing(by: NSDecimalNumber(floatLiteral: 12.0))
//
//        return "Just" + " \(priceValue(value: divided))" + " / " + "Month"
//    }
//
//    private func periodOnly() -> String {
//        if subscriptionPeriod != nil {
//            if introductoryPrice == nil {
//                return periodDescriptionOnlyShort()
//            }
//            switch subscriptionPeriod!.unit {
//                case .day, .week:
//                    return "per week after"
//                case .month:
//                    return "per month after"
//                case .year:
//                    return "per year after"
//                default:
//                    return ""
//            }
//        } else {
//            return "one purchase"
//        }
//    }
//
//    private func periodName(from period: SKProductSubscriptionPeriod?) -> String {
//
//        if period == nil {return ""}
//
//        switch period!.unit {
//            case .day:
//                return "day"
//            case .week:
//                return "week"
//            case .month:
//                return "month"
//            case .year:
//                return "year"
//            default:
//                return ""
//        }
//    }
//}
