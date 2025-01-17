//
//  Apphud, Inc.swift
//  Apphud, Inc
//
//  Created by ren6 on 28/04/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#endif
import StoreKit
import Foundation
import UserNotifications
import SwiftUI

internal let apphud_sdk_version = "3.5.9"

// MARK: - Initialization

/**
 Entry point of the Apphud SDK. It provides access to all its features.

 Main class of Apphud SDK.
 
 #### Related Articles
 -  [Apphud SDK Initialization](https://docs.apphud.com/docs/ios)
 -  [Observer Mode](https://docs.apphud.com/docs/observer-mode)
 -  [Fetch Products](https://docs.apphud.com/docs/managing-products)
 -  [Make a Purchase](https://docs.apphud.com/docs/making-purchases)
 -  [Check Subscription Status](https://docs.apphud.com/docs/checking-subscription-status)
 */
final public class Apphud: NSObject {

    /**
     Initializes Apphud SDK. Call this during the app's launch.

     - parameter apiKey: Required. Your API key.
     - parameter userID: Optional. Provide your own unique user identifier, or if `nil`, a UUID will be generated.
     - parameter observerMode: Optional. Sets SDK to Observer (Analytics) mode. Pass `true` if you handle product purchases with your own code, or `false` if you use the `Apphud.purchase(..)` method. The default value is `false`. This mode influences analytics and data collection behaviors.
     - parameter callback: Optional. Called when the user is successfully registered in Apphud [or retrieved from cache]. Use this to fetch raw placements or paywalls.
     */
    @MainActor
    public static func start(apiKey: String, userID: String? = nil, observerMode: Bool = false, callback: ((ApphudUser) -> Void)? = nil) {
        ApphudInternal.shared.initialize(apiKey: apiKey, inputUserID: userID, observerMode: observerMode)
        ApphudInternal.shared.performWhenUserRegistered { callback?(ApphudInternal.shared.currentUser!) }
    }

    /**
    Initializes Apphud SDK with User ID & Device ID pair. Not recommended for use unless you know what you are doing.

    - parameter apiKey: Required. Your api key.
    - parameter userID: Optional. You can provide your own unique user identifier. If `nil` passed then UUID will be generated instead.
    - parameter deviceID: Optional. You can provide your own unique device identifier. If `nil` passed then UUID will be generated instead.
    - parameter observerMode: Optional. Sets SDK to Observer (Analytics) mode. If you purchase products by your own code, then pass `true`. If you purchase products using `Apphud.purchase(product)` method, then pass `false`. Default value is `false`.
    - parameter callback: Optional. Called when user is successfully registered in Apphud [or used from cache]. Use this to fetch raw placements or paywalls.
    */
    @MainActor
    public static func startManually(apiKey: String, userID: String? = nil, deviceID: String? = nil, observerMode: Bool = false, callback: ((ApphudUser) -> Void)? = nil) {
        ApphudInternal.shared.initialize(apiKey: apiKey, inputUserID: userID, inputDeviceID: deviceID, observerMode: observerMode)
        ApphudInternal.shared.performWhenUserRegistered { callback?(ApphudInternal.shared.currentUser!) }
    }

    /**
     Updates the user ID. Use this when you need to change the user identifier during the app's runtime.

     - parameter userID: Required. The new user ID value.
     */
    @MainActor
    @objc public static func updateUserID(_ userID: String) {
        ApphudInternal.shared.updateUserID(userID: userID)
    }

    /**
     Returns the current userID that identifies the user across multiple devices.

     Note: This value may change during runtime. Observe the `apphudDidChangeUserID(_ userID: String)` delegate method for changes.
     */
    @MainActor @objc public static func userID() -> String {
        return ApphudInternal.shared.currentUserID
    }

    /**
     Returns the current device ID. Use this method if you need to implement a custom logout/login flow by saving a User ID & Device ID pair for each app user. This allows for a more controlled management of user sessions and device associations.

     - Returns: A string representing the current device ID.
     */
    @MainActor @objc public static func deviceID() -> String {
        return ApphudInternal.shared.currentDeviceID
    }

    /**
     Logs out the current user, clears all saved data, and resets the SDK to an uninitialized state. After calling this method, you must reinitialize the SDK with `Apphud.start(...)` or `Apphud.manually(...)` for a new user.

     This method is particularly useful in scenarios involving custom logout/login flows, allowing you to manage the subscription status of each user more effectively.

     __Note__: If the previous user had an active subscription, a new logged-in user can still restore purchases on the same device. In this case, both users will be merged under the account of the user with the active subscription, due to the Apple ID being tied to the device.
     */
    @objc public static func logout() async {
        await ApphudInternal.shared.logout()
    }

    /**
     Sets a delegate for receiving Apphud SDK callbacks.

     - parameter delegate: Required. An object conforming to the ApphudDelegate protocol. This delegate will receive various SDK events and state updates, enabling custom handling of subscription and user status changes.
     */
    public static func setDelegate(_ delegate: ApphudDelegate) {
        ApphudInternal.shared.delegate = delegate
    }

    /**
     Sets a UI delegate for handling UI-related interactions with the Apphud SDK.

     - parameter delegate: Required. An object conforming to the ApphudUIDelegate protocol. This delegate is responsible for handling UI events and interactions that arise from the SDK, such as presenting subscription screens or handling user input.
     */
    @objc public static func setUIDelegate(_ delegate: ApphudUIDelegate) {
        ApphudInternal.shared.uiDelegate = delegate
    }

    // MARK: - Placements & Paywalls

    /**
     Asynchronously retrieves the paywall placements configured in Product Hub > Placements, potentially altered based on the user's involvement in A/B testing, if any. Awaits until the inner `SKProduct`s are loaded from the App Store.

     A placement is a specific location within a user's journey (such as onboarding, settings, etc.) where its internal paywall is intended to be displayed. See documentation for details: https://docs.apphud.com/docs/placements.
     
     - Important: In case of network issues this method may return empty array. To get the possible error use `fetchPlacements` method instead.

     For immediate access without awaiting `SKProduct`s, use `rawPlacements()` method.
     - parameter maxAttempts: Number of request attempts before throwing an error. Must be between 1 and 10. Default value is 3.
     - Returns: An array of `ApphudPlacement` objects, representing the configured placements.
     */
    @MainActor
    public static func placements(maxAttempts: Int = APPHUD_DEFAULT_RETRIES) async -> [ApphudPlacement] {
        await withUnsafeContinuation { continuation in
            ApphudInternal.shared.fetchOfferingsFull(maxAttempts: maxAttempts) { error in
                continuation.resume(returning: ApphudInternal.shared.placements)
            }
        }
    }

    /**
    A list of paywall placements, potentially altered based on the user's involvement in A/B testing, if any. A placement is a specific location within a user's journey (such as onboarding, settings, etc.) where its internal paywall is intended to be displayed.

     - Important: This function doesn't await until inner `SKProduct`s are loaded from the App Store. That means placements may or may not have inner StoreKit products at the time you call this function.

     - Important: This function will return empty array if user is not yet loaded, or placements are not set up in the Product Hub.

    To get placements with awaiting for StoreKit products, use await Apphud.placements() or
     Apphud.placementsDidLoadCallback(...) functions.

    - Returns: An array of `ApphudPlacement` objects, representing the configured placements.
    */
    @MainActor public static func rawPlacements() -> [ApphudPlacement] {
        ApphudInternal.shared.placements
    }

    /**
     Asynchronously retrieve a specific placement by identifier configured in Product Hub > Placements, potentially altered based on the user's involvement in A/B testing, if any. Awaits until the inner `SKProduct`s are loaded from the App Store.

     A placement is a specific location within a user's journey (such as onboarding, settings, etc.) where its internal paywall is intended to be displayed.

     - Important: In case of network issues this method may return empty array. To get the possible error use `fetchPlacements` method instead.
     
     For immediate access without awaiting `SKProduct`s, use `ApphudDelegate`'s `userDidLoad` method or the callback in `Apphud.start(...)`.

     - parameter identifier: The unique identifier for the desired placement.
     - Returns: An optional `ApphudPlacement` object if found, or `nil` if no matching placement is found.
     */
    @MainActor
    public static func placement(_ identifier: String) async -> ApphudPlacement? {
        await placements().first(where: { $0.identifier == identifier })
    }

    /**
     Retrieves the placements configured in Product Hub > Placements, potentially altered based on the user's involvement in A/B testing, if any. Awaits until the inner `SKProduct`s are loaded from the App Store.

     A placement is a specific location within a user's journey (such as onboarding, settings, etc.) where its internal paywall is intended to be displayed.

     For immediate access without awaiting `SKProduct`s, use `ApphudDelegate`'s `userDidLoad` method or the callback in `Apphud.start(...)`.
     - parameter maxAttempts: Number of request attempts before throwing an error. Must be between 1 and 10. Default value is 3.
     - parameter callback: A closure that takes an array of `ApphudPlacement` objects and returns void.
     - parameter error: Optional ApphudError that may occur while fetching products from the App Store. You might want to retry the request if the error comes out.
     */
    @MainActor
    public static func fetchPlacements(maxAttempts: Int = APPHUD_DEFAULT_RETRIES, _ callback: @escaping ([ApphudPlacement], ApphudError?) -> Void) {
        ApphudInternal.shared.fetchOfferingsFull(maxAttempts: maxAttempts) { error in
            callback(ApphudInternal.shared.placements, error)
        }
    }
    
    /**
     Disables automatic paywall and placement requests during the SDK's initial setup. Developers must explicitly call `fetchPlacements` or `await placements()` methods at a later point in the app's lifecycle to fetch placements with inner paywalls.
     
     Example:
     
        ```swift
        Apphud.start(apiKey: "your_api_key")
        Apphud.deferPlacements()
        ...
        Apphud.fetchPlacements { placements in
           // Handle fetched placements
        }
        ```
     
     Note: You can use this method alongside `forceFlushUserProperties` to achieve real-time user segmentation based on custom user properties.
     */
    public static func deferPlacements() {
        ApphudInternal.shared.deferPlacements = true
    }

    /**
     Retrieves the paywalls configured in Product Hub > Paywalls, potentially altered based on the user's involvement in A/B testing, if any. Awaits until the inner `SKProduct`s are loaded from the App Store.

     For immediate access without awaiting `SKProduct`s, use `ApphudDelegate`'s `userDidLoad` method or the callback in `Apphud.start(...)`.

     - Important: This is deprecated method. Retrieve paywalls from within placements instead. See documentation for details: https://docs.apphud.com/docs/placements

     - parameter maxAttempts: Number of request attempts before throwing an error. Must be between 1 and 10. Default value is 3.
     - parameter callback: A closure that takes an array of `ApphudPaywall` objects and returns void.
     - parameter error: Optional ApphudError that may occur while fetching products from the App Store. You might want to retry the request if the error comes out.
     */
    @available(*, deprecated, message: "Deprecated in favor of fetchPlacements(...)")
    @MainActor
    @objc public static func paywallsDidLoadCallback(maxAttempts: Int = APPHUD_DEFAULT_RETRIES, _ callback: @escaping ([ApphudPaywall], Error?) -> Void) {
        ApphudInternal.shared.fetchOfferingsFull(maxAttempts: maxAttempts) { error in
            callback(ApphudInternal.shared.paywalls, error)
        }
    }

    /**
     Notifies Apphud when a purchase process is initiated from a paywall in `Observer Mode`, enabling the use of A/B experiments. This method should be called right before executing your own purchase method, and it's specifically required only when the SDK is in Observer Mode.

     - Important: Observer mode only. Call this method immediately before your custom purchase method.

     - parameter paywallIdentifier: Required. The Paywall ID from Apphud Product Hub > Paywalls.
     - parameter placementIdentifier: Optional. The Placement ID from Apphud Product Hub > Placements if using placements; otherwise, pass `nil`.

     Example usage:
     ```swift
     Apphud.willPurchaseProductFrom(paywallIdentifier: "main_paywall", placementIdentifier: "some_placement")
     YourClass.purchase(someProduct)
     ```
     */
    @objc public static func willPurchaseProductFrom(paywallIdentifier: String, placementIdentifier: String?) {
        ApphudInternal.shared.willPurchaseProductFrom(paywallId: paywallIdentifier, placementId: placementIdentifier)
    }

    /**
    Logs a "Paywall Shown" event which is required for A/B Testing analytics.

    - parameter paywall: The `ApphudPaywall` instance that was shown to the user.
    */
    @objc public static func paywallShown(_ paywall: ApphudPaywall) {
        ApphudLoggerService.shared.paywallShown(paywall: paywall)
    }

    /**
    Logs a "Paywall Closed" event which is required for A/B Testing analytics.

    - parameter paywall: The `ApphudPaywall` instance that was shown to the user.
    */
    @objc public static func paywallClosed(_ paywall: ApphudPaywall) {
        ApphudLoggerService.shared.paywallClosed(paywallId: paywall.id, placementId: paywall.placementId)
    }

    // MARK: - Products
    /**
     Fetches product structures (`Product` structs) asynchronously from the App Store. This method throws an error if there is a problem in fetching the products.

     - Returns: An array of `Product` structs. Ensure that you have added the product identifiers in the Apphud dashboard (Apphud > Product Hub > Products) for this method to return valid results.

     - Throws: An error if the products could not be fetched successfully.
     */
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, visionOS 1.0, *)
    public static func fetchProducts() async throws -> [Product] {
        if ApphudAsyncStoreKit.shared.productsLoaded {
            return await ApphudAsyncStoreKit.shared.products()
        } else {
            return try await ApphudAsyncStoreKit.shared.fetchProducts()
        }
    }

    /**
     Fetches `SKProduct` objects asynchronously from the App Store. This method is used to retrieve the products that you have configured in the Apphud dashboard (Apphud > Product Hub > Products).
     - parameter maxAttempts: Number of request attempts before throwing an error. Must be between 1 and 10. Default value is 3.
     
     - Returns: An array of `SKProduct` objects corresponding to the products added in the Apphud > Product Hub > Products section.
     */
    @objc public static func fetchSKProducts(maxAttempts: Int = APPHUD_DEFAULT_RETRIES) async -> [SKProduct] {
        await withUnsafeContinuation { continuation in
            Apphud.fetchProducts(maxAttempts: maxAttempts) { prds, _ in continuation.resume(returning: prds) }
        }
    }

    /**
     Retrieves an array of existing `SKProduct` objects or fetches products from the App Store that have been added in the Apphud Dashboard under Product Hub > Products.

     - parameter maxAttempts: Number of request attempts before throwing an error. Must be between 1 and 10. Default value is 3.
     - parameter callback: A closure that is called upon completion. It returns an array of `SKProduct` objects and an optional `Error` if the fetch operation encountered any issues.
     - Returns: The method doesn't return a value directly but instead provides the result through the `callback` parameter.

     - Important: Best practice is to manage products using placements configurations in the Apphud Product Hub > Placements, rather than directly fetching products. Implementing placements logic via the dashboard allows for more organized and scalable management of your app's placements and paywalls.
     */
    @objc public static func fetchProducts(maxAttempts: Int = APPHUD_DEFAULT_RETRIES, _ callback: @escaping ([SKProduct], Error?) -> Void) {
        ApphudInternal.shared.refreshStoreKitProductsWithCallback(maxAttempts: maxAttempts, callback: callback)
    }

    /**
     Retrieves an array of `SKProduct` objects that were added in the Apphud dashboard (Apphud > Product Hub > Products). This property returns `nil` if the products have not been fetched from the App Store yet.

     - Note: This method returns `nil` if the products have not yet been fetched from the App Store. To ensure functionality, configure Product Hub in Apphud.

     - Important: As a best practice, instead of using this method directly, implement your paywall logic through the Apphud Dashboard for more effective paywall management and to leverage Apphud's functionalities.
     */
    @objc(storeKitProducts)
    public static var products: [SKProduct]? {
        guard ApphudStoreKitWrapper.shared.products.count > 0 else {
            return nil
        }

        return ApphudStoreKitWrapper.shared.products
    }

    /**
     Retrieves an `SKProduct` object based on its product identifier. This method is used to access product details for items you've added in the Apphud Dashboard under Product Hub > Products.

     - parameter productIdentifier: The unique identifier for the product. Ensure this identifier matches one added in the Apphud Dashboard.
     - Returns: An optional `SKProduct` object corresponding to the provided identifier. Returns `nil` if the product has not been fetched from the App Store yet.

     - Note: This method will return `nil` if the product associated with the given identifier has not yet been fetched from the App Store. Ensure that your product identifiers are correctly set up in the App Store Connect and Apphud Dashboard.
     - Important: Best practice is to manage and retrieve products through placements configurations added in the Apphud Dashboard under Product Hub > Placements. Direct use of this method is discouraged in favor of a more structured approach to managing your app's placements and paywalls.
     */
    @objc public static func product(productIdentifier: String) -> SKProduct? {
        ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == productIdentifier})
    }

    /**
     Retrieves the corresponding `ApphudProduct` for a given StoreKit 2 `Product` struct, if it exists.

     - parameter product: The `Product` struct from StoreKit 2.
     - Returns: An optional `ApphudProduct` struct that matches the given `Product` struct.
     */
    @MainActor @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    public static func apphudProductFor(_ product: Product) -> ApphudProduct? {
        ApphudInternal.shared.allAvailableProducts.first(where: { $0.productId == product.id })
    }

    /**
     Asynchronously fetches permission groups configured in the Apphud > Product Hub. Note that this method may return an empty array at the first app launch until products are loaded. Groups are cached on the device.

     - Returns: An optional array of `ApphudGroup` objects, representing the permission groups.
     */
    @objc public static func permissionGroups() async -> [ApphudGroup]? {
        if let groups = await ApphudInternal.shared.permissionGroups {
            return groups
        } else {
            return await ApphudInternal.shared.fetchPermissionGroups()
        }
    }

    // MARK: - Make Purchase

    /**
     Initiates the purchase of an `ApphudProduct` object from an `ApphudPaywall` and optionally from `ApphudPlacement` and automatically submits the App Store Receipt to Apphud.

     - parameter product: Required. An `ApphudProduct` object from your `ApphudPaywall`. Configure placements and paywalls in Apphud Dashboard > Product Hub before using.
     - parameter callback: Optional. Returns an `ApphudPurchaseResult` object.
     - Note: You can purchase products using your own code; Apphud will still receive the App Store receipt.
     */
    @MainActor @objc(purchaseApphudProduct:callback:)
    public static func purchase(_ product: ApphudProduct, callback: ((ApphudPurchaseResult) -> Void)?) {
        ApphudInternal.shared.purchase(productId: product.productId, product: product, validate: true, callback: callback)
    }

    /**
     Deprecated. Initiates the purchase of a product by its identifier. Use this method if you do not implement Apphud Placements logic.

     - parameter productId: Required. The identifier of the product to purchase.
     - parameter callback: Optional. Returns an `ApphudPurchaseResult` object.
     - Note: A/B Experiments will not work with this method. Use `ApphudProduct` objects with Placements for A/B experiments.
     - Important: Best practice is to use Apphud Placements configured in Apphud Dashboard > Product Hub > Placements.
     */
    @MainActor @objc(purchaseById:callback:)
    public static func purchase(_ productId: String, callback: ((ApphudPurchaseResult) -> Void)?) {
        ApphudInternal.shared.purchase(productId: productId, product: nil, validate: true, callback: callback)
    }

    /**
     Initiates an asynchronous purchase of a `Product` struct and submits the transaction to Apphud. A/B testing functionality is not supported with this method.

     - parameter product: Required. A `Product` struct from StoreKit 2.
     - parameter isPurchasing: Optional. A binding to a Boolean value indicating the purchase process status. Useful in SwiftUI.
     - Returns: An `ApphudAsyncPurchaseResult` struct.
     */
    #if os(iOS) || os(tvOS) || os(macOS) || os(watchOS)
    @MainActor
    @available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
    public static func purchase(_ product: Product, isPurchasing: Binding<Bool>? = nil) async -> ApphudAsyncPurchaseResult {
        await ApphudAsyncStoreKit.shared.purchase(product: product, apphudProduct: apphudProductFor(product), isPurchasing: isPurchasing)
    }
    #else
    @MainActor
    public static func purchase(_ product: Product, scene: UIScene, isPurchasing: Binding<Bool>? = nil) async -> ApphudAsyncPurchaseResult {
        await ApphudAsyncStoreKit.shared.purchase(product: product,scene: scene, apphudProduct: apphudProductFor(product), isPurchasing: isPurchasing)
    }
    #endif
    /**
     Initiates an asynchronous purchase of an `ApphudProduct` object from an `ApphudPaywall` and automatically submits the App Store Receipt to Apphud.

     - parameter product: Required. An `ApphudProduct` object from your `ApphudPaywall`. Configure placements and paywalls in Apphud Dashboard > Product Hub before using.
     - parameter isPurchasing: Optional. A binding to a Boolean value indicating the purchase process status. Useful in SwiftUI.
     - Returns: An `ApphudPurchaseResult` object.
     */
    @MainActor
    @available(iOS 13.0.0, macOS 11.0, watchOS 6.0, tvOS 13.0, *)
    public static func purchase(_ product: ApphudProduct, isPurchasing: Binding<Bool>? = nil) async -> ApphudPurchaseResult {
        await ApphudInternal.shared.purchase(productId: product.productId, product: product, validate: true, isPurchasing: isPurchasing)
    }

    /**
     Purchases a subscription with a promotional offer and automatically submits the App Store Receipt to Apphud.

     - parameter apphudProduct: Required. An `ApphudProduct` object representing the subscription to be purchased.
     - parameter discountID: Required. The identifier of the `SKProductDiscount` to be applied to the purchase.
     - parameter callback: Optional. Returns an `ApphudPurchaseResult` object upon completion.

     - Note: This method automatically sends the in-app purchase receipt to Apphud.
     */
    @objc public static func purchasePromo(apphudProduct: ApphudProduct, discountID: String, _ callback: ((ApphudPurchaseResult) -> Void)?) {
        ApphudInternal.shared.purchasePromo(skProduct: nil, apphudProduct: apphudProduct, discountID: discountID, callback: callback)
    }
    @objc public static func purchasePromo(_ skProduct: SKProduct, discountID: String, _ callback: ((ApphudPurchaseResult) -> Void)?) {
        ApphudInternal.shared.purchasePromo(skProduct: skProduct, apphudProduct: nil, discountID: discountID, callback: callback)
    }

    /**
     Presents the offer code redemption sheet on iOS 14 and later. This allows users to redeem offer codes provided by Apple.

     - Available on iOS 14.0 and later.
     */
    @available(iOS 14.0, *)
    @objc public static func presentOfferCodeRedemptionSheet() {
        ApphudStoreKitWrapper.shared.presentOfferCodeSheet()
    }

    /**
     Experimental purchase method allowing the passing of a custom value for purchases. This custom value is sent to AppsFlyer and Facebook for value optimization, such as subscription Lifetime Value (LTV) or Average Revenue Per Paying User (ARPPU), in USD.

     - parameter product: Required. An `ApphudProduct` object for the purchase.
     - parameter value: Required. The custom value in USD to be sent for analytics.
     - parameter callback: Optional. Returns an `ApphudPurchaseResult` object.

     - Note: Contact your support manager for detailed guidance on using this method.
     */
    @MainActor @objc(purchaseApphudProduct:value:callback:)
    public static func purchase(_ product: ApphudProduct, value: Double, callback: ((ApphudPurchaseResult) -> Void)?) {
        ApphudInternal.shared.purchase(productId: product.productId, product: product, validate: true, value: value, callback: callback)
    }

    /**
     Sets a custom value for purchases in Observer Mode. This value is sent to AppsFlyer and Facebook for value optimization, like subscriptions LTV or ARPPU, in USD. Call this method before starting a purchase.

     - parameter value: Required. The custom value in USD.
     - parameter productId: Required. The product identifier for which the custom value is set.
     - Note: This method is intended for use only in Observer Mode. If you are making purchases with Apphud, use the `purchase(_:value:callback:)` method.
     - Important: Contact your support manager for detailed guidance on using this method.
     */
    @objc public static func setCustomPurchaseValue(_ value: Double, productId: String) {
        ApphudStoreKitWrapper.shared.purchasingValue = ApphudCustomPurchaseValue(productId, value)
    }

    // MARK: - Check Status

    /**
     Determines if the user has active premium access through a subscription or a non-renewing purchase (lifetime).
     
     __If you have consumable purchases, do not use this method in current SDK version.__

     - Important: Do not use this method if you offer consumable in-app purchases (like coin packs) as the SDK does not differentiate consumables from non-consumables.
     - Returns: `true` if the user has an active subscription or an active non-renewing purchase.
     */
    @objc public static func hasPremiumAccess() -> Bool {
        ApphudInternal.shared.isPremium
    }

    /**
     Checks if the user has an active premium subscription.

     - Important: If your app includes lifetime (non-consumable) or consumable purchases, you should use the `Apphud.isNonRenewingPurchaseActive(productIdentifier:)` method to check their status.
     - Returns: `true` if the user currently has an active subscription.
     */
    @objc public static func hasActiveSubscription() -> Bool {
        ApphudInternal.shared.hasActiveSubscription
    }

    /**
     Notification triggered when any subscription or non-renewing purchase is purchased or updated. The SDK also checks for updates when the app becomes active. This notification can be used to update the UI in response to purchase changes and is also useful in SwiftUI contexts.

     - Returns: The notification name for subscription or non-renewing purchase updates.
     */
    @objc public static func didUpdateNotification() -> Notification.Name {
        return Notification.Name("ApphudDidUpdateNotification")
    }

    /**
     Retrieves the most recently purchased subscription object for the current user. Subscriptions are cached on the device.

     - Note: A non-nil return value does not guarantee that the subscription is active. Use the `Apphud.hasActiveSubscription()` method or check the `isActive` property of the subscription to determine if premium functionality should be unlocked for the user.
     - Returns: The most recent `ApphudSubscription` object if available, otherwise `nil`.
     */
    @MainActor public static func subscription() -> ApphudSubscription? {
        return ApphudInternal.shared.currentUser?.subscriptions.first
    }

    /**
     Retrieves all subscriptions that the user has ever purchased. This method is useful if your app has more than one subscription group.

     - Returns: An array of `ApphudSubscription` objects representing all subscriptions ever purchased by the user, or `nil` if the SDK is not initialized.
     */
    @MainActor public static func subscriptions() -> [ApphudSubscription]? {
        guard ApphudInternal.shared.isInitialized else {
            apphudLog(ApphudInitializeGuardText, forceDisplay: true)
            return nil
        }
        return ApphudInternal.shared.currentUser?.subscriptions
    }

    /**
     Retrieves all non-renewing purchases (consumables, non-consumables, or non-renewing subscriptions) made by the user. Purchases are cached on the device and sorted by purchase date. Note that Apphud only tracks consumables if they were purchased after integrating the Apphud SDK.

     - Returns: An array of `ApphudNonRenewingPurchase` objects representing all standard in-app purchases made by the user, or `nil` if the SDK is not initialized.
     */
    @MainActor public static func nonRenewingPurchases() -> [ApphudNonRenewingPurchase]? {
        guard ApphudInternal.shared.isInitialized else {
            apphudLog(ApphudInitializeGuardText, forceDisplay: true)
            return nil
        }
        return ApphudInternal.shared.currentUser?.purchases
    }

    /**
     Checks if the user has an active non-renewing purchase with a specific product identifier. This includes consumables, non-consumables, or non-renewing subscriptions. Note that Apphud only tracks consumables if they were purchased after integrating the Apphud SDK.

     - parameter productIdentifier: The product identifier for the in-app purchase to check.
     - Returns: `true` if the user has an active purchase with the given product identifier; `false` if the product is refunded, never purchased, or inactive.
     */
    @MainActor public static func isNonRenewingPurchaseActive(productIdentifier: String) -> Bool {
        nonRenewingPurchases()?.first(where: {$0.productId == productIdentifier})?.isActive() ?? false
    }

    // MARK: - Restore Purchases

    /**
     Restores the user's purchases asynchronously. This method should be called when the user taps the "Restore" button in your app.

     - Returns: An optional `Error`. If the error is `nil`, you can check the user's premium status using the `Apphud.hasActiveSubscription()` or `Apphud.hasPremiumAccess()` methods.
     */
    @MainActor @objc @discardableResult public static func restorePurchases() async -> Error? {
        return await withUnsafeContinuation({ continunation in
            Task { @MainActor in
                ApphudInternal.shared.restorePurchases { _, _, error in
                    continunation.resume(returning: error)
                }
            }
        })
    }

    /**
     Implements the `Restore Purchases` mechanism. This method sends the current App Store Receipt to Apphud and returns information about the user's subscriptions and in-app purchases.

     - parameter callback: Required. A closure that returns an array of `ApphudSubscription` objects, an array of `ApphudNonRenewingPurchase` objects, and an optional `Error`.
     - Note: The presence of a subscription in the callback does not guarantee that it is active. You should check the `isActive()` property on each subscription.
     */
    @MainActor public static func restorePurchases(callback: @escaping ([ApphudSubscription]?, [ApphudNonRenewingPurchase]?, Error?) -> Void) {
        ApphudInternal.shared.restorePurchases(callback: callback)
    }

    // MARK: - Receipts

    /**
     Retrieves the base64-encoded App Store receipt string, if available.

     - Returns: A base64-encoded string representing the App Store receipt, or nil if the receipt is not available.
    */
    @objc public static func appStoreReceipt() -> String? {
        apphudReceiptDataString()
    }

    /**
    Fetches raw receipt information in an ApphudReceipt model class. This is useful for accessing details like the original_application_version.

    - parameter completion: A closure that is called with the ApphudReceipt object containing the receipt information.
    */
    @objc public static func fetchRawReceiptInfo(_ completion: @escaping (ApphudReceipt?) -> Void) {
        ApphudReceipt.getRawReceipt(completion: completion)
    }

    // MARK: - Promotionals
    /**
     Grants a free promotional subscription to the user. This method updates the user's subscription status, and after this, the `hasActiveSubscription()` method will return `true`.

     - parameter daysCount: Required. The number of days for the free premium access. For a lifetime promotional, pass an extremely high value, like 100000.
     - parameter productId: Optional*. It's recommended to provide the Product Id of the promotional subscription. Read the note below for more details.
     - parameter permissionGroup: Optional*. The Permission Group of the promotional subscription. Use this parameter if you have multiple permission groups.
     - parameter callback: Optional. Returns `true` if the promotional subscription was successfully granted.

     - Note: Either `productId` (recommended) or `permissionGroup` should be passed, or both parameters can be `nil`. If both `productId` and `permissionGroup` are provided, `productId` will be used. [Documentation](https://docs.apphud.com/docs/product-hub)
     */
    @objc public static func grantPromotional(daysCount: Int, productId: String?, permissionGroup: ApphudGroup?, callback: ApphudBoolCallback?) {
        ApphudInternal.shared.grantPromotional(daysCount, permissionGroup, productId: productId, callback: callback)
    }

    // MARK: - User Properties

    /**
     Sets a custom user property in Apphud. The value assigned to this property must be of one of the following types: `Int`, `Float`, `Double`, `Bool`, `String`, `NSNumber`, `NSString`, `NSNull`, or `nil`.

     Example:
     ````swift
     Apphud.setUserProperty(key: .init("custom_prop_1"), value: 0.5)
     ````

     There are several built-in keys provided by Apphud, each expecting a specific value type:

     - `.email`: The user's email. The value must be a `String`.
     - `.name`: The user's name. The value must be a `String`.
     - `.phone`: The user's phone number. The value must be a `String`.
     - `.age`: The user's age. The value must be an `Int`.
     - `.gender`: The user's gender. The value must be a `String`, with accepted values being "male", "female", or "other".
     - `.cohort`: The cohort the user belongs to, typically indicating when they installed the app. The value must be a `String`.

     Parameters:
     - `key`: Required. This can be initialized with a custom `String` or by using one of the built-in keys provided by Apphud.
     - `value`: Required/Optional. The value to be set for the specified key. Pass `nil` or `NSNull` to remove the property from Apphud.
     - `setOnce`: Optional. A Boolean value where passing `true` will make the property non-updatable, meaning it can only be set once.

     Note: Custom user properties are useful for segmenting your user base within Apphud for targeted analysis or marketing efforts. Ensure the values you set are accurate and relevant to your app's functionality and user experience.
     */
    @objc public static func setUserProperty(key: ApphudUserPropertyKey, value: Any?, setOnce: Bool = false) {
        ApphudInternal.shared.setUserProperty(key: key, value: value, setOnce: setOnce, increment: false)
    }
    
    /**
     This method sends all user properties immediately to Apphud. Should be used for audience segmentation in placements based on user properties.
    
     Example:
     ````swift
     Apphud.start(apiKey: "api_key")
     Apphud.deferPlacements()
     
     Apphud.setUserProperty(key: .init("key_name"), value: "key_value")
     
     Apphud.forceFlushUserProperties { done in
        // now placements will respect user properties that have been sent previously
         Apphud.fetchPlacements { placements, error in
         }
     }
     ```
     */
    
    public static func forceFlushUserProperties(completion: @escaping (Bool) -> Void) {
        ApphudInternal.shared.performWhenUserRegistered {
            ApphudInternal.shared.flushUserProperties(force: true, completion: completion)
        }
    }

    /**

    Increments a custom user property. Value must be one of: `Int`, `Float`, `Double` or `NSNumber`.

    Example:
     ```swift
    Apphud.incrementUserProperty(key: .init("progress"), by: 0.5)
     ```

    - parameter key: Required. Use your custom string key or some of built-in keys.
    - parameter by: Required/Optional. You can pass negative value to decrement.

    */
    @objc public static func incrementUserProperty(key: ApphudUserPropertyKey, by: Any) {
        ApphudInternal.shared.setUserProperty(key: key, value: by, setOnce: false, increment: true)
    }

    // MARK: - Rules & Screens Methods
    #if os(iOS)
    /**
     Presents an Apphud Screen that was previously delayed for presentation. This is typically used in conjunction with the `apphudShouldShowScreen` delegate method, where returning `false` would delay the Screen's presentation.

     - Note: Call this method to show a Screen that was delayed due to specific conditions or user actions in your app. This helps in managing the user experience more effectively, ensuring Screens are presented at the most appropriate time.
     */
    @MainActor
    @objc public static func showPendingScreen() {
        return ApphudRulesManager.shared.showPendingScreen()
    }

    /**
     Retrieves the view controller for the Screen that is pending presentation. This screen is usually triggered by a pending Rule in Apphud. You have the option to present this Screen manually or use the `showPendingScreen` method.

     - Returns: An optional `UIViewController` representing the Screen that is pending for presentation. Returns `nil` if there is no Screen currently pending.
     - Note: Use this method to retrieve the view controller for a delayed Screen if you need to present it manually or modify it before presentation.
     */
    @MainActor
    @objc public static func pendingScreenController() -> UIViewController? {
        return ApphudRulesManager.shared.pendingController
    }

    /**
     Retrieves the Apphud Rule associated with a Screen that was delayed for presentation.

     - Returns: An optional `ApphudRule` object representing the Rule that triggered the delayed Screen. Returns `nil` if there is no pending Rule.
     - Note: This method is useful for understanding which Rule led to the delay of a Screen and can help in making decisions on when to present the Screen or take other actions.
     */
    @MainActor
    @objc public static func pendingRule() -> ApphudRule? {
        return ApphudRulesManager.shared.pendingRule()
    }
    #endif
    // MARK: - Push Notifications

    /**
     Submits the device's push token to Apphud. This is essential for enabling Apphud to send push notifications to the device.

     - parameter token: The push token, provided as a Data object.
     - parameter callback: An optional closure that returns `true` if the token was successfully sent to Apphud.

     - Note: Ensure that the push token is obtained correctly from your app's notification setup process before submitting it to Apphud.
     */
    @objc public static func submitPushNotificationsToken(token: Data, callback: ApphudBoolCallback?) {
        ApphudInternal.shared.submitPushNotificationsToken(token: token, callback: callback)
    }

    /**
     Submits the device's push token to Apphud as a String. This method provides an alternative way to submit the token if you have it in a string format.

     - parameter token: The push token as a String object.
     - parameter callback: An optional closure that returns `true` if the token was successfully sent to Apphud.

     - Note: Use this method if your push token is already converted into a String format. Ensure the token is accurate for successful submission.
     */
    @objc public static func submitPushNotificationsTokenString(string: String, callback: ApphudBoolCallback?) {
        ApphudInternal.shared.submitPushNotificationsTokenString(string, callback: callback)
    }

    #if os(iOS)
    /**
     Handles an incoming push notification payload. This method is used to process Rules-related notifications created by Apphud.

     - parameter apsInfo: The payload of the push notification.
     - Returns: `true` if the push notification was successfully handled by Apphud.

     - Note: This method should be used in your push notification handling logic to allow Apphud to manage notifications related to its Rules.
     */
    @MainActor
    @discardableResult @objc public static func handlePushNotification(apsInfo: [AnyHashable: Any]) -> Bool {
        return ApphudRulesManager.shared.handleNotification(apsInfo)
    }
    #endif
    // MARK: - Attribution

    /**
     Submits Device Identifiers (IDFA and IDFV) to Apphud. These identifiers may be required for marketing and attribution platforms such as AppsFlyer, Facebook, Singular, etc.
     
     Best practice is to call this method right after SDK's `start(...)` method and once again after getting IDFA.

     - parameter idfa: IDFA. Identifier for Advertisers. If you request IDFA using App Tracking Transparency framework, you can call this method again after granting access.
     - parameter idfv: IDFV. Identifier for Vendor. Can be passed right after SDK's `start` method.
     */
    @objc public static func setDeviceIdentifiers(idfa: String?, idfv: String?) {
        ApphudInternal.shared.performWhenUserRegistered {
            ApphudInternal.shared.deviceIdentifiers = (idfa, idfv)
        }
    }
    @available(*, unavailable, renamed: "setDeviceIdentifiers(idfa:idfv:)")
    @objc public static func setAdvertisingIdentifier(_ idfa: String) {}

    /**
     Submits attribution data to Apphud from your chosen attribution network provider.

     - parameter data: Required. The attribution data dictionary.
     - parameter provider: Required. The name of the attribution provider.
     - parameter identifier: Optional. An identifier that matches between Apphud and the Attribution provider.
     - parameter callback: Optional. A closure that returns `true` if the data was successfully sent to Apphud.

     - Note: Properly setting up attribution data is key for tracking and optimizing user acquisition strategies and measuring the ROI of marketing campaigns.
     */
    @objc public static func addAttribution(data: [AnyHashable: Any]?, from provider: ApphudAttributionProvider, identifer: String? = nil, callback: ApphudBoolCallback?) {
        ApphudInternal.shared.addAttribution(rawData: data, from: provider, identifer: identifer, callback: callback)
    }
    
    /**
        Web-to-Web flow only. Attempts to attribute the user with the provided attribution data.
        If the `data` parameter contains either `aph_user_id`, `apphud_user_id`,  `email` or `apphud_user_email`, the SDK will submit this information to the Apphud server.
        The server will return a restored web user if found; otherwise, the callback will return `false`.
     
        __Important:__ If the callback returns `true`, it doesn't mean the user has premium access, you should still call `Apphud.hasPremiumAccess()`.

        Additionally, the delegate methods `apphudSubscriptionsUpdated` and `apphudDidChangeUserID` may be called.

        The callback returns `true` if the user is successfully attributed via the web and includes the updated `ApphudUser` object.
        After this callback, you can check the `Apphud.hasPremiumAccess()` method, which should return `true` if the user has premium access.

        - Parameters:
          - data: A dictionary containing the attribution data.
          - callback: A closure that returns a boolean indicating whether the web attribution was successful, and the updated `ApphudUser` object.
        */
    @MainActor
    public static func attributeFromWeb(data: [AnyHashable: Any], callback: @escaping (Bool, ApphudUser?) -> Void) {
        ApphudInternal.shared.tryWebAttribution(attributionData: data, completion: callback)
    }

    // MARK: - Eligibility Checks

    /**
     Checks whether the given product is eligible for an introductory offer, which includes `free trial`, `pay as you go`, or `pay up front` options.

     Eligibility criteria:
     - New subscribers are always eligible.
     - Lapsed subscribers who renew are eligible if they haven't previously used an introductory offer for the given product or any product within the same subscription group.

     - parameter product: Required. The `SKProduct` object for which you want to check introductory offer eligibility.
     - parameter callback: A closure that returns `true` if the product is eligible for an introductory offer.

     - Note: This check is essential for offering introductory prices correctly according to Apple's guidelines.
     */
    @objc public static func checkEligibilityForIntroductoryOffer(product: SKProduct, callback: @escaping ApphudBoolCallback) {
        guard product.introductoryPrice != nil else {
            callback(false)
            return
        }

        ApphudInternal.shared.checkEligibilitiesForIntroductoryOffers(products: [product]) { result in
            callback(result[product.productIdentifier] ?? true)
        }
    }

    /**
     Checks whether the given product is eligible for any of its promotional offers.

     Eligibility criteria:
     - Only customers who have already purchased a subscription are eligible for promotional offers for the given product or any product within the same subscription group.

     - parameter product: Required. The `SKProduct` object for which you want to check promotional offer eligibility.
     - parameter callback: A closure that returns `true` if the product is eligible for any of its promotional offers.

     - Note: Use this method to determine if a user can be offered a discount on a subscription renewal or upgrade.
     */
    @objc public static func checkEligibilityForPromotionalOffer(product: SKProduct, callback: @escaping ApphudBoolCallback) {
        ApphudInternal.shared.checkEligibilitiesForPromotionalOffers(products: [product]) { result in
            callback(result[product.productIdentifier] ?? false)
        }
    }

    /**
     Checks the eligibility for promotional offers for multiple products simultaneously.

     - parameter products: Required. An array of `SKProduct` objects for which you want to check promotional offers eligibility.
     - parameter callback: A closure that returns a dictionary with product identifiers as keys and boolean values indicating eligibility.

     - Note: This method is useful for batch processing multiple products, especially when setting up a store or special offers section in your app.
     */
    @objc public static func checkEligibilitiesForPromotionalOffers(products: [SKProduct], callback: @escaping ApphudEligibilityCallback) {
        ApphudInternal.shared.checkEligibilitiesForPromotionalOffers(products: products, callback: callback)
    }

    /**
     Checks the eligibility for introductory offers for multiple products simultaneously.

     - parameter products: Required. An array of `SKProduct` objects for which you want to check introductory offers eligibility.
     - parameter callback: A closure that returns a dictionary with product identifiers as keys and boolean values indicating eligibility.

     - Note: Use this method to efficiently determine introductory offer eligibility for a range of products, aiding in dynamic pricing and offer strategies.
     */
    @objc public static func checkEligibilitiesForIntroductoryOffers(products: [SKProduct], callback: @escaping ApphudEligibilityCallback) {
        ApphudInternal.shared.checkEligibilitiesForIntroductoryOffers(products: products, callback: callback)
    }

    // MARK: - Other

    /**
     Opts the user out of tracking. This method should be called before SDK initialization. When called, it prevents the tracking of certain user parameters like IDFA, IDFV, and IP address by Apphud.

     - Note: Consider the privacy implications and ensure compliance with relevant data protection regulations when opting users out of tracking.
     */
    @objc public static func optOutOfTracking() {
        ApphudUtils.shared.optOutOfTracking = true
    }

    /**
     Enables debug logs for the Apphud SDK. This method should be called before initializing the SDK.

     - Note: Debug logs are helpful for development and troubleshooting but should be disabled in production builds for performance and security reasons.
     */
    @objc public static func enableDebugLogs() {
        ApphudUtils.enableDebugLogs()
    }

    /**
     Determines if the current build is running in a sandbox environment, such as during development, testing, or TestFlight, as opposed to a production App Store build.

     - Returns: `true` if the build is a sandbox (development, TestFlight) build; `false` if it's an App Store build.

     - Note: Use this method to differentiate behavior or configurations between development/testing and production environments.
     */
    @objc public static func isSandbox() -> Bool {
        return apphudIsSandbox()
    }
    
    @available(*, unavailable, message: "No longer needed. Purchases migrate automatically. Just remove this code.")
    @MainActor public static func migratePurchasesIfNeeded(callback: @escaping ([ApphudSubscription]?, [ApphudNonRenewingPurchase]?, Error?) -> Void) {}
    
    /**
     Override default paywalls and placements cache timeout value. Default cache value is 9000 seconds (25 hours).
     If expired, will make SDK to disregard cache and force refresh paywalls and placements.
     Call it only if keeping paywalls and placements up to date is critical for your app business.
     
        **Must call before SDK initialization.**
     
     - parameter value: New value in seconds. Must be between 0 and 172800 (48 hours).
     */
    @objc public static func setPaywallsCacheTimeout(_ value: TimeInterval) {
        ApphudInternal.shared.setCacheTimeout(value)
    }
    
    /**
     Explicitly loads fallback paywalls from the json file, if it was added to the project resources.
     By default, SDK automatically tries to load paywalls from the JSON file, if possible.
     However, developer can also call this method directly for more control.
     For more details, visit https://docs.apphud.com/docs/paywalls#set-up-fallback-mode
    */
    @MainActor 
    public static func loadFallbackPaywalls(callback: @escaping ([ApphudPaywall]?, ApphudError?) -> Void) {
        ApphudInternal.shared.executeFallback(callback: callback)
    }

}
