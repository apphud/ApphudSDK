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
@objc public protocol ApphudDelegate {
    /**
        Returns array of subscriptions that user ever purchased. Empty array means user never purchased a subscription. If you have just one subscription group in your app, you will always receive just one subscription in an array.
     
        This method is called when subscription is purchased or updated (for example, status changed from `trial` to `expired` or `isAutorenewEnabled` changed to `false`). SDK also checks for subscription updates when app becomes active.
     */
    @objc optional func apphudSubscriptionsUpdated(_ subscriptions: [ApphudSubscription])

    /**
        Called when any of non renewing purchases changes. Called when purchase is made or has been refunded.
     */
    @objc optional func apphudNonRenewingPurchasesUpdated(_ purchases: [ApphudNonRenewingPurchase])

    /**
        Called when user ID has been changed. Use this if you implement integrations with Analytics services.
     
        Please read following if you implement integrations: `https://docs.apphud.com/docs/en/sdk-integration#user-identifier-and-integrations`
     
        This delegate method is called in 2 cases:
     
        * When Apphud has merged two users into a single user (for example, after user has restored purchases from his another device).
        Merging users is done in the following way: after App Store receipt has been sent to Apphud, server tries to find the same receipt in the database.
        If the same App Store receipt has been found, Apphud merges two users into a single user with two devices and then returns an original userID.
     
        __Note__: Only subscriber devices are mergable. If non-premium user uses the app from two different devices, Apphud won't be able to know that these devices belong to the same user.
     
        * After manual call of `updateUserID(userID : String)` method.
     */
    @objc optional func apphudDidChangeUserID(_ userID: String)

    /**
     Deprecated. Use `func getPaywalls` method instead.
        
     This method gets called when products are fetched from App Store. Returns optional Error from StoreKit, if exists.
     */
    @objc optional func apphudDidFetchStoreKitProducts(_ products: [SKProduct], _ error: Error?)
    @objc optional func apphudDidFetchStoreKitProducts(_ products: [SKProduct])

    /**
     Implements mechanism of purchasing In-App Purchase initiated directly from the App Store page.
     
     You must return a callback block which will be called when a payment is finished. If you don't implement this method or return `nil` then a payment will not start; you can also save the product and return `nil` to initiate a payment later by yourself. Read Apple documentation for details: https://developer.apple.com/documentation/storekit/in-app_purchase/promoting_in-app_purchases
     */
    @objc optional func apphudShouldStartAppStoreDirectPurchase(_ product: SKProduct) -> ((ApphudPurchaseResult) -> Void)?

    /**
        Optional. Specify a list of product identifiers to fetch from the App Store.
        If you don't implement this method, then product identifiers will be fetched from Apphud servers.
     
        Implementing this delegate method gives you more reliabality on fetching products and a little more speed on loading due to skipping Apphud request, but also gives less flexibility because you have to hardcode product identifiers this way.
     */
    @objc optional func apphudProductIdentifiers() -> [String]

    /**
        Called when Apphud SDK detects a purchase that was made outside of Apphud SDK purchase methods. It is also useful to intercept purchases made using Promo Codes for in-app purchases. If user redeems promo code for in-app purchase in the App Store, then opens the app, this delegate method will be called, so you will be able to handle successful payment on your side.
        
        Return `true` if you would like Apphud SDK to finish this transaction. If you return `false`, then you must call `SKPaymentQueue.default().finishTransaction(transaction)`.
        See optional `transaction` property of `result` object.
     */
    @objc optional func apphudDidObservePurchase(result: ApphudPurchaseResult) -> Bool

    /**
        Called when Apphud SDK detects a deferred or interrupted purchase, this may happen when SCA confirmation is needed, in the case of parental control and some other cases
     */
    @objc optional func handleDeferredTransaction(transaction: SKPaymentTransaction)
}
