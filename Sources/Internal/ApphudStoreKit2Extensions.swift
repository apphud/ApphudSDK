//
//  ApphudStoreKit2Extensions.swift
//  ApphudSDK
//
//  StoreKit 2 counterparts of the SKProduct-based helpers: builds the
//  `product_info` payload for POST /v1/subscriptions from a StoreKit 2 Product.
//  Field set mirrors SKProduct.apphudSubmittableParameters(_:) byte for byte.
//

import Foundation
import StoreKit

extension Product {

    var apphudIsTrial: Bool {
        subscription?.introductoryOffer?.paymentMode == .freeTrial
    }

    /// SK2 equivalent of `SKProduct.apphudSubmittableParameters(_:)`.
    /// Locale-derived fields (country/currency) come from `priceFormatStyle` on iOS 16+,
    /// with a fallback to the SK1 products feeder below iOS 16.
    func apphudSubmittableParameters(_ purchased: Bool = false) -> [String: Any] {
        var params: [String: Any] = [
            "product_id": id,
            "price": NSDecimalNumber(decimal: price).floatValue
        ]

        if let currencyCode = apphudCurrencyCode() {
            params["currency_code"] = currencyCode
        }

        if let countryCode = apphudCountryCode() {
            params["country_code"] = countryCode
        }

        if let intro = subscription?.introductoryOffer, let introParams = Self.apphudOfferParameters(offer: intro, prefix: "intro_") {
            params.merge(introParams, uniquingKeysWith: { $1 })
        }

        if let value = ApphudStoreKitWrapper.shared.purchasingValue, value.productId == id, purchased == true {
            params["custom_purchase_value"] = value.value
        }

        if let period = subscription?.subscriptionPeriod, period.value > 0 {
            params["unit"] = Self.apphudUnitString(unit: period.unit)
            params["units_count"] = period.value
        }

        let promoOffers = (subscription?.promotionalOffers ?? []).compactMap { offer -> [String: Any]? in
            guard var offerParams = Self.apphudOfferParameters(offer: offer, prefix: "") else { return nil }
            offerParams["offer_id"] = offer.id ?? ""
            return offerParams
        }
        if promoOffers.count > 0 {
            params["promo_offers"] = promoOffers
        }

        return params
    }

    func apphudPromoIdentifiers() -> [String] {
        (subscription?.promotionalOffers ?? []).compactMap { $0.id }
    }

    internal func apphudCurrencyCode() -> String? {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *) {
            return priceFormatStyle.currencyCode
        }
        return apphudSK1Fallback()?.apphudLegacyCurrencyCode()
    }

    internal func apphudCountryCode() -> String? {
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, visionOS 1.0, *) {
            return priceFormatStyle.locale.apphudRegionCode()
        }
        return apphudSK1Fallback()?.apphudLegacyCountryCode()
    }

    private func apphudSK1Fallback() -> SKProduct? {
        ApphudStoreKitWrapper.shared.products.first(where: { $0.productIdentifier == id })
    }

    // MARK: - Offer / period mapping

    private static func apphudUnitString(unit: Product.SubscriptionPeriod.Unit) -> String {
        switch unit {
        case .day:
            return "day"
        case .week:
            return "week"
        case .month:
            return "month"
        case .year:
            return "year"
        @unknown default:
            return ""
        }
    }

    private static func apphudPaymentModeString(_ mode: Product.SubscriptionOffer.PaymentMode) -> String? {
        switch mode {
        case .payUpFront:
            return "pay_up_front"
        case .payAsYouGo:
            return "pay_as_you_go"
        case .freeTrial:
            return "trial"
        default:
            return nil
        }
    }

    /// Shared shape for intro (`intro_` prefix) and promo (no prefix) offer payloads.
    private static func apphudOfferParameters(offer: Product.SubscriptionOffer, prefix: String) -> [String: Any]? {
        guard let mode = apphudPaymentModeString(offer.paymentMode) else { return nil }
        return [
            "\(prefix)unit": apphudUnitString(unit: offer.period.unit),
            "\(prefix)units_count": offer.period.value,
            "\(prefix)periods_count": offer.periodCount,
            "\(prefix)mode": mode,
            "\(prefix)price": NSDecimalNumber(decimal: offer.price).floatValue
        ]
    }
}

extension SKProduct {
    func apphudLegacyCurrencyCode() -> String? {
        #if os(visionOS)
        return priceLocale.currency?.identifier
        #else
        return priceLocale.currencyCode
        #endif
    }

    func apphudLegacyCountryCode() -> String? {
        #if os(visionOS)
        return priceLocale.region?.identifier
        #else
        return priceLocale.regionCode
        #endif
    }
}

extension Locale {
    func apphudRegionCode() -> String? {
        #if os(visionOS)
        return region?.identifier
        #else
        if #available(iOS 16.0, macOS 13.0, tvOS 16.0, watchOS 9.0, *) {
            return region?.identifier
        }
        return regionCode
        #endif
    }
}
