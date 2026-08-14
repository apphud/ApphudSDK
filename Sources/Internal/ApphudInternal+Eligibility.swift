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

    // MARK: - StoreKit 2 eligibility by product identifiers

    @available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
    internal func checkIntroEligibilitiesSK2(productIds: [String]) async -> [String: Bool] {
        var response = [String: Bool]()
        for id in productIds {
            response[id] = true // can purchase intro by default
            if let product = try? await ApphudAsyncStoreKit.shared.fetchProduct(id) {
                if let subscription = product.subscription {
                    // A product with no introductory offer configured cannot be eligible
                    // for one, regardless of the subscription group's history.
                    if subscription.introductoryOffer == nil {
                        response[id] = false
                    } else {
                        response[id] = await subscription.isEligibleForIntroOffer
                    }
                } else {
                    response[id] = false // not a subscription
                }
            }
        }
        return response
    }

    @available(iOS 15.0, macOS 12.0, watchOS 8.0, tvOS 15.0, *)
    internal func checkPromoEligibilitiesSK2(productIds: [String]) async -> [String: Bool] {
        var response = [String: Bool]()

        // Collect subscription group ids of all products the user ever transacted with.
        var purchasedGroupIds = Set<String>()
        for await result in StoreKit.Transaction.all {
            if case .verified(let transaction) = result,
               let product = try? await ApphudAsyncStoreKit.shared.fetchProduct(transaction.productID),
               let groupId = product.subscription?.subscriptionGroupID {
                purchasedGroupIds.insert(groupId)
            }
        }

        let userSubscriptionIds = await Set((currentUser?.subscriptions ?? []).map { $0.productId })

        for id in productIds {
            if userSubscriptionIds.contains(id) {
                response[id] = true
                continue
            }
            response[id] = false // cannot purchase offer by default
            if let product = try? await ApphudAsyncStoreKit.shared.fetchProduct(id),
               let groupId = product.subscription?.subscriptionGroupID {
                response[id] = purchasedGroupIds.contains(groupId)
            }
        }
        return response
    }

    // MARK: - Eligibilities API

    internal func checkEligibilitiesForPromotionalOffers(products: [SKProduct], callback: @escaping ApphudEligibilityCallback) {

        performWhenUserRegistered(allowFailure: true) {
            apphudLog("User registered, check promo eligibility")

            if self.currentUser == nil {
                apphudLog("Failed to register user, aborting Promo eligibility checks.", forceDisplay: true)
                var response = [String: Bool]()
                for product in products {
                    response[product.productIdentifier] = false // cannot purchase offer by default
                }
                callback(response)
            } else {
                // StoreKit 2 checks the transaction history locally — no receipt upload needed.
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

            if self.currentUser == nil {
                apphudLog("Failed to register user, aborting Intro eligibility checks.", forceDisplay: true)
                var response = [String: Bool]()
                for product in products {
                    response[product.productIdentifier] = true // can purchase intro by default
                }
                callback(response)
            } else {
                // StoreKit 2 answers intro eligibility locally — no receipt upload needed.
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
