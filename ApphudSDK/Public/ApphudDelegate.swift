//
//  ApphudDelegate.swift
//  ApphudSDK
//
//  Created by ren6 on 01/07/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import StoreKit

/**
 A public protocol that provides access to Apphud's main public methods, describing the behavior of the user and the state of his subscriptions.
 */

@available(macOS 10.14.4, *)
public protocol ApphudDelegate {
    /**
     Called when there is an update to the user's subscriptions. This includes new purchases, updates to existing subscriptions (e.g., status change from `trial` to `expired`, or change in `isAutorenewEnabled`).

     This method provides an array of `ApphudSubscription` objects representing all subscriptions the user has ever purchased. An empty array indicates the user has never purchased a subscription. In apps with only one subscription group, this array will typically contain only one subscription.

     - parameter subscriptions: An array of `ApphudSubscription` objects reflecting the user's subscription history and status.
     - Note: The SDK checks for subscription updates both when this method is called and when the app becomes active, ensuring up-to-date subscription data.
     */
    func apphudSubscriptionsUpdated(_ subscriptions: [ApphudSubscription])

    /**
     Called when there is a change in the user's non-renewing purchases. This can occur when a new purchase is made or if a purchase is refunded.

     - parameter purchases: An array of `ApphudNonRenewingPurchase` objects, each representing a non-renewing purchase made by the user.
     - Note: Use this method to track and respond to changes in the user's non-renewing purchases, such as unlocking or revoking access to content or features.
     */
    func apphudNonRenewingPurchasesUpdated(_ purchases: [ApphudNonRenewingPurchase])

    /**
     Called when the user's ID in Apphud changes. This is important for maintaining continuity in integrations with analytics services.

     This method is called in two scenarios:
     1. When Apphud merges two user accounts into one. This can happen if a user restores purchases from another device and Apphud identifies the same App Store receipt in its database. In this case, the two accounts are merged, and the original userID is returned.
        - __Note__: Only subscriber devices are mergeable. Non-premium users on multiple devices cannot be merged unless they have a subscription.
     2. After manually calling the `updateUserID(userID: String)` method.

     - parameter userID: The new user ID assigned to the user.
     - Note: For more information on user ID changes and their implications, refer to Apphud's documentation on initialization and user merging: `https://docs.apphud.com/docs/initialization`
     */
    func apphudDidChangeUserID(_ userID: String)

    /**
     Implements the mechanism for handling In-App Purchases initiated directly from the App Store page.

     This method should return a callback block that will be executed when a payment is finished. If you don't implement this method or return `nil`, the payment will not start. Alternatively, you can save the product and return `nil` to initiate the payment later by yourself. For more details, refer to Apple's documentation on promoting In-App Purchases: https://developer.apple.com/documentation/storekit/in-app_purchase/promoting_in-app_purchases

     - parameter product: The `SKProduct` object representing the product to be purchased.
     - Returns: A closure of type `((ApphudPurchaseResult) -> Void)` that is called upon the completion of the purchase.
     */
    func apphudShouldStartAppStoreDirectPurchase(_ product: SKProduct) -> ((ApphudPurchaseResult) -> Void)?

    /**
     Called when the Apphud SDK detects a purchase made outside of its standard purchase methods. This is particularly useful for handling purchases made with Promo Codes.

     - parameter result: An `ApphudPurchaseResult` object containing details of the purchase.
     - Returns: `true` if you want the Apphud SDK to finish the transaction. If you return `false`, you must manually call `SKPaymentQueue.default().finishTransaction(transaction)` on the transaction.
     - Note: This method allows you to intercept and process purchases that occur through mechanisms like promo code redemption.
     */
    func apphudDidObservePurchase(result: ApphudPurchaseResult) -> Bool

    /**
     Called when the Apphud SDK detects a deferred or interrupted purchase. This can happen in scenarios like required Strong Customer Authentication (SCA), parental control approvals, etc.

     - parameter transaction: The `SKPaymentTransaction` object representing the deferred or interrupted transaction.
     - Note: Use this method to handle cases where transaction completion is delayed or requires additional user interaction.
     */
    func handleDeferredTransaction(transaction: SKPaymentTransaction)

    /**
    Called once per app lifecycle when the user is registered in Apphud or retrieved from cache. The `user` parameter contains a record of all purchases tracked by Apphud and associated raw placements and paywalls for that user.

    - parameter user: An instance of `ApphudUser` representing a user in Apphud.
    */
    func userDidLoad(user: ApphudUser)

    /**
     Called when paywalls are fully loaded with their associated `SKProducts`. This method serves a similar purpose to the `Apphud.paywallsDidLoadCallback {}` method.

     - parameter paywalls: An array of `ApphudPaywall` objects, now fully loaded with their respective `SKProducts`.
     - Note: Use this method to update your UI or logic once all paywall data, including `SKProduct` details, are fully loaded.
     */
    func paywallsDidFullyLoad(paywalls: [ApphudPaywall])

    /**
     Called when placements are fully loaded with their associated Paywalls and StoreKit products.

     - parameter placements: An array of `ApphudPlacement` objects.
     - Note: This is the point at which you can be sure that all placement data, including paywalls and associated StoreKit products, is available for use.
     */
    func placementsDidFullyLoad(placements: [ApphudPlacement])
}

@available(macOS 10.14.4, *)
public extension ApphudDelegate {
    func apphudSubscriptionsUpdated(_ subscriptions: [ApphudSubscription]) {}
    func apphudNonRenewingPurchasesUpdated(_ purchases: [ApphudNonRenewingPurchase]) {}
    func apphudDidChangeUserID(_ userID: String) {}
    func apphudShouldStartAppStoreDirectPurchase(_ product: SKProduct) -> ((ApphudPurchaseResult) -> Void)? { nil }
    func apphudDidObservePurchase(result: ApphudPurchaseResult) -> Bool { false }
    func handleDeferredTransaction(transaction: SKPaymentTransaction) {}
    func userDidLoad(user: ApphudUser) {}
    func paywallsDidFullyLoad(paywalls: [ApphudPaywall]) {}
    func placementsDidFullyLoad(placements: [ApphudPlacement]) {}
}
