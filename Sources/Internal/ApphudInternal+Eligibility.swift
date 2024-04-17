//
//  ApphudInternal+Eligibility.swift
//  apphud
//
//  Created by Renat on 01.07.2020.
//  Copyright © 2020 Apphud Inc. All rights reserved.
//

import Foundation
import StoreKit

extension ApphudInternal {

    // MARK: - Eligibilities API

    internal func checkEligibilitiesForPromotionalOffers(products: [SKProduct], callback: @escaping ApphudEligibilityCallback) {

        performWhenUserRegistered(allowFailure: true) {
            apphudLog("User registered, check promo eligibility")

            let didSendReceiptForPromoEligibility = "ReceiptForPromoSent"

            // not found subscriptions, try to restore and try again
            if self.currentUser == nil {
                apphudLog("Failed to register user, aborting Promo eligibility checks.", forceDisplay: true)
                var response = [String: Bool]()
                for product in products {
                    response[product.productIdentifier] = false // cannot purchase offer by default
                }
                callback(response)
            } else if self.currentUser?.subscriptions.count ?? 0 == 0 && !UserDefaults.standard.bool(forKey: didSendReceiptForPromoEligibility) {
                if let receiptString = apphudReceiptDataString() {
                    apphudLog("Restoring subscriptions for promo eligibility check")
                    self.submitReceipt(product: nil, apphudProduct: nil, transaction: nil, receiptString: receiptString, notifyDelegate: true, eligibilityCheck: true, callback: { _ in
                        UserDefaults.standard.set(true, forKey: didSendReceiptForPromoEligibility)
                        Task {
                            let response = await self._checkPromoEligibilitiesForRegisteredUser(products: products)
                            apphudPerformOnMainThread { callback(response) }
                        }
                    })
                } else {
                    apphudLog("Receipt not found on device, impossible to determine eligibility. This is probably missing sandbox receipt issue. This should never not happen on production, because there receipt always exists. For more information see: https://docs.apphud.com/docs/testing-troubleshooting. Exiting", forceDisplay: true)
                    var response = [String: Bool]()
                    for product in products {
                        response[product.productIdentifier] = false // cannot purchase offer by default
                    }
                    callback(response)
                }
            } else {
                apphudLog("Has purchased subscriptions or has checked receipt for promo eligibility")
                Task {
                    let response = await self._checkPromoEligibilitiesForRegisteredUser(products: products)
                    apphudPerformOnMainThread { callback(response) }
                }
            }
        }
    }

    private func _checkPromoEligibilitiesForRegisteredUser(products: [SKProduct]) async -> [String: Bool] {

        var response = [String: Bool]()
        for product in products {
            response[product.productIdentifier] = false
        }

        apphudLog("Products fetched, check promo eligibility")

        for product in products {
            if await (currentUser?.subscriptions.first(where: { $0.productId == product.productIdentifier })) != nil {
                response[product.productIdentifier] = true
            } else if #available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *) {
                for await result in StoreKit.Transaction.all {
                    if case .verified(let transaction) = result {
                        let productStruct = try? await ApphudAsyncStoreKit.shared.fetchProduct(transaction.productID)
                        if productStruct?.subscription != nil && productStruct?.subscription?.subscriptionGroupID == product.subscriptionGroupIdentifier {
                            response[product.productIdentifier] = true
                        }
                    }
                }

            } else {
                response[product.productIdentifier] = await currentUser?.subscriptions.count ?? 0 > 0
            }
        }

        apphudLog("Finished promo checking, response: \(response as AnyObject)")
        return response
    }

    /// Checks introductory offers eligibility (includes free trial, pay as you go or pay up front)
    internal func checkEligibilitiesForIntroductoryOffers(products: [SKProduct], callback: @escaping ApphudEligibilityCallback) {

        performWhenUserRegistered(allowFailure: true) {
            apphudLog("User registered, check intro eligibility")

            // not found subscriptions, try to restore and try again

            let didSendReceiptForIntroEligibility = "ReceiptForIntroSent"
            if self.currentUser == nil {
                apphudLog("Failed to register user, aborting Intro eligibility checks.", forceDisplay: true)
                var response = [String: Bool]()
                for product in products {
                    response[product.productIdentifier] = true // can purchase intro by default
                }
                callback(response)
            } else if self.currentUser?.subscriptions.count ?? 0 == 0 && !UserDefaults.standard.bool(forKey: didSendReceiptForIntroEligibility) {
                if let receiptString = apphudReceiptDataString() {
                    apphudLog("Restoring subscriptions for intro eligibility check")
                    self.submitReceipt(product: nil, apphudProduct: nil, transaction: nil, receiptString: receiptString, notifyDelegate: true, eligibilityCheck: true, callback: { _ in
                        UserDefaults.standard.set(true, forKey: didSendReceiptForIntroEligibility)
                        Task {
                            let response = await self._checkIntroEligibilitiesForRegisteredUser(products: products)
                            apphudPerformOnMainThread {
                                callback(response)
                            }
                        }
                    })
                } else {
                    apphudLog("Receipt not found on device, impossible to determine eligibility. This is probably missing sandbox receipt issue. This should never not happen on production, because there receipt always exists. For more information see: https://docs.apphud.com/docs/testing-troubleshooting. Exiting", forceDisplay: true)
                    var response = [String: Bool]()
                    for product in products {
                        response[product.productIdentifier] = true // can purchase intro by default
                    }
                    callback(response)
                }
            } else {
                apphudLog("Has purchased subscriptions or has checked receipt for intro eligibility")
                Task {
                    let response = await self._checkIntroEligibilitiesForRegisteredUser(products: products)
                    apphudPerformOnMainThread {
                        callback(response)
                    }
                }
            }
        }
    }

    private func _checkIntroEligibilitiesForRegisteredUser(products: [SKProduct]) async -> [String: Bool] {

        var response = [String: Bool]()
        for product in products {
            response[product.productIdentifier] = true
        }

        for product in products {
            if #available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *) {
                if let productStruct = try? await ApphudAsyncStoreKit.shared.fetchProduct(product.productIdentifier), let sub = productStruct.subscription {
                    response[product.productIdentifier] = await sub.isEligibleForIntroOffer
                }
            } else if let sub = await currentUser?.subscriptions.first(where: { $0.productId == product.productIdentifier }) {
                let eligible = !sub.isIntroductoryActivated
                response[product.productIdentifier] = eligible
            }
        }

        apphudLog("Finished intro checking, response: \(response as AnyObject)")

        return response
    }
}
