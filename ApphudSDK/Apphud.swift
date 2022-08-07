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

internal let apphud_sdk_version = "2.8.5"

/**
 Public Callback object provide -> [String: Bool]
 */
public typealias ApphudEligibilityCallback = (([String: Bool]) -> Void)

/**
 Public Callback object provide -> Bool
 */
public typealias ApphudBoolCallback = ((Bool) -> Void)

/// List of available attribution providers
/// has to make Int in order to support Objective-C
@objc public enum ApphudAttributionProvider: Int {
    case appsFlyer
    case adjust
    case appleSearchAds // For iOS 14.2 or lower devices only, Apple Search Ads attribution via iAd.framework
    case appleAdsAttribution // For iOS 14.3+ devices only, Apple Search Ads attribution via AdServices.framework
    case firebase
    
    @available(*, deprecated, message: "Facebook integration is no longer needed from SDK and has been voided. You can safely remove this line of code.")
    case facebook

    /**
     case branch
     Branch integration doesn't require any additional code from Apphud SDK
     More details: https://docs.apphud.com/integrations/attribution/branch
     */

    func toString() -> String {
        switch self {
        case .appsFlyer:
            return "AppsFlyer"
        case .adjust:
            return "Adjust"
        case .facebook:
            return "Facebook"
        case .appleSearchAds:
            return "Apple Search Ads"
        case .appleAdsAttribution:
            return "Apple Ads Attribution"
        case .firebase:
            return "Firebase"
        }
    }
}

// MARK: - Initialization

/**
 Entry point of the Apphud SDK. It provides access to all its features.

 Main class of Apphud SDK.
 
 #### Related Articles
 -  [Apphud SDK Initialization](https://docs.apphud.com/getting-started/sdk-integration/ios#initialise-sdk)
 -  [Observer Mode](https://docs.apphud.com/getting-started/observer-mode)
 -  [Fetch Products](https://docs.apphud.com/getting-started/sdk-integration/ios#get-paywalls-version-2.3.0-or-above)
 -  [Check Subscription Status](https://docs.apphud.com/getting-started/sdk-integration/ios#check-subscription-status)
 */

@available(OSX 10.14.4, *)
@available(iOS 11.2, *)
final public class Apphud: NSObject {

    /**
     Initializes Apphud SDK. You should call it during app launch.
     
     - parameter apiKey: Required. Your api key.
     - parameter userID: Optional. You can provide your own unique user identifier. If `nil` passed then UUID will be generated instead.
     - parameter observerMode: Optional. Sets SDK to Observer (i.e. Analytics) mode. If you purchase products by your own code, then pass `true`. If you purchase products using `Apphud.purchase(..)` method, then pass `false`. Default value is `false`.
     */
    @objc public static func start(apiKey: String, userID: String? = nil, observerMode: Bool = false) {
        ApphudInternal.shared.initialize(apiKey: apiKey, inputUserID: userID, observerMode: observerMode)
    }

    /**
    Initializes Apphud SDK with User ID & Device ID pair. Not recommended for use unless you know what you are doing.

    - parameter apiKey: Required. Your api key.
    - parameter userID: Optional. You can provide your own unique user identifier. If `nil` passed then UUID will be generated instead.
    - parameter deviceID: Optional. You can provide your own unique device identifier. If `nil` passed then UUID will be generated instead.
    - parameter observerMode: Optional. Sets SDK to Observer (Analytics) mode. If you purchase products by your own code, then pass `true`. If you purchase products using `Apphud.purchase(product)` method, then pass `false`. Default value is `false`.
    */
    @objc public static func startManually(apiKey: String, userID: String? = nil, deviceID: String? = nil, observerMode: Bool = false) {
        ApphudInternal.shared.initialize(apiKey: apiKey, inputUserID: userID, inputDeviceID: deviceID, observerMode: observerMode)
    }

    /**
     Updates user ID value.
     - parameter userID: Required. New user ID value.
     */
    @objc public static func updateUserID(_ userID: String) {
        ApphudInternal.shared.updateUserID(userID: userID)
    }

    /**
     Returns current userID that identifies user across his multiple devices. 
     
     This value may change in runtime, see `apphudDidChangeUserID(_ userID : String)` delegate method for details.
     */
    @objc public static func userID() -> String {
        return ApphudInternal.shared.currentUserID
    }

    /**
     Returns current device ID. You should use it only if you want to implement custom logout/login flow by saving User ID & Device ID pair for each app user.
     */
    @objc public static func deviceID() -> String {
        return ApphudInternal.shared.currentDeviceID
    }

    /**
     Logs out current user, clears all saved data and resets SDK to uninitialized state. You will need to call `Apphud.start()` or `Apphud.startManually()` again to initilize SDK with a new user.

     This might be useful if you have your custom logout/login flow and you want to take control of each logged-in user's subscription status.

     __Note__: If previous user had active subscription, the new logged-in user can still restore purchases on this device and both users will be merged under the previous paid one, because Apple ID is tied to a device.
     */
    @objc public static func logout() {
        ApphudInternal.shared.logout()
    }

    /**
     Set a delegate.
     - parameter delegate: Required. Any ApphudDelegate conformable object.
     */
    @objc public static func setDelegate(_ delegate: ApphudDelegate) {
        ApphudInternal.shared.delegate = delegate
    }

    /**
     Set a UI delegate.
     - parameter delegate: Required. Any ApphudUIDelegate conformable object.
     */
    @objc public static func setUIDelegate(_ delegate: ApphudUIDelegate) {
        ApphudInternal.shared.uiDelegate = delegate
    }

    // MARK: - Make Purchase

    /**
     Returns paywalls configured in Apphud Dashboard > Product Hub > Paywalls. Each paywall contains an array of `ApphudProduct` objects that you use for purchase.
     `ApphudProduct` is Apphud's wrapper around StoreKit's `SKProduct`.
     
     Returns `nil` if paywalls are not yet populated with SKProducts from the App Store. To get notified when paywalls are ready to use, use `paywallsDidLoadCallback` – when it's called, paywalls are populated with their `SKProducts`.
     */
    @objc public static var paywalls: [ApphudPaywall]? {
        if ApphudInternal.shared.paywallsAreReady {
            // only return paywalls when their SKProducts are fetched from the App Store.
            return ApphudInternal.shared.paywalls
        } else {
            return nil
        }
    }

    /**
     Returns paywalls configured in Apphud Dashboard > Product Hub > Paywalls. Each paywall contains an array of `ApphudProduct` objects that you use for purchase.
     `ApphudProduct` is Apphud's wrapper around StoreKit's `SKProduct`.
     
     This callback is called when paywalls are populated with their StoreKit products. Callback is called immediately if paywalls are already loaded.
     It is safe to call this method multiple times – previous callback will not be overwritten, but will be added to array and once paywalls are loaded, all callbacks will be called.
    */
    @objc public static func paywallsDidLoadCallback(_ callback: @escaping ([ApphudPaywall]) -> Void) {
        if ApphudInternal.shared.paywallsAreReady {
            callback(ApphudInternal.shared.paywalls)
        } else {
            ApphudInternal.shared.customPaywallsLoadedCallbacks.append(callback)
        }
    }

    /**
     __Deprecated__. Fetches paywalls configured in Apphud dashboard. This makes an API request to Apphud. Always check if there are cached paywalls on device by using paywalls method.
     */
    @available(*, deprecated, message: "Use `func paywallsDidLoadCallback` method instead.")
    @objc public static func getPaywalls(callback: @escaping ([ApphudPaywall]?, Error?) -> Void) {
        self.paywallsDidLoadCallback { (paywalls) in
            callback(paywalls, nil)
        }
    }
    
    /**
        If you want to use A/B experiments while running SDK in `Observer Mode` you should manually send paywall identifier to Apphud using this method.
         
        Example:
     ```swift
        Apphud.willPurchaseProductFromPaywall("main_paywall")
        YourClass.purchase(someProduct)
     ```
     - Note: You have to add paywalls in Apphud Dashboard > Product Hub > Paywalls.
     - Important: You must call this method right before your own purchase method.
     */
    @objc public static func willPurchaseProductFromPaywall(_ identifier: String) {
        ApphudInternal.shared.willPurchaseProductFromPaywall(identifier: identifier)
    }

    /**
     This notification is sent when `SKProduct`s are fetched from the App Store. Note that you have to add all product identifiers in Apphud Dashboard > Product Hub > Products.
     
     You can use `productsDidFetchCallback` callback or observe for `didFetchProductsNotification()` or implement `apphudDidFetchStoreKitProducts` delegate method. Use whatever you like most.
     
     Best practise is not to use this method, but implement paywalls logic by adding your paywall configuration in Apphud Dashboard > Product Hub > Paywalls.
     */
    @objc public static func didFetchProductsNotification() -> Notification.Name {
        return Notification.Name("ApphudDidFetchProductsNotification")
    }

    /**
    This callback is called when `SKProduct`s are fetched from the App Store. Note that you have to add all product identifiers in Apphud Dashboard > Product Hub > Products.
    
    You can use `productsDidFetchCallback` callback or observe for `didFetchProductsNotification()` or implement `apphudDidFetchStoreKitProducts` delegate method. Use whatever you like most.
     
     Best practise is not to use this method, but implement paywalls logic by adding your paywall configuration in Apphud Dashboard > Product Hub > Paywalls.
    */
    @objc public static func productsDidFetchCallback(_ callback: @escaping ([SKProduct], Error?) -> Void) {
        ApphudInternal.shared.customProductsFetchedBlocks.append(callback)
    }
    
    /**
     Refreshes `SKProduct`s from the App Store. You have to add all product identifiers in Apphud Dashboard > Product Hub > Products.
     
     Best practise is not to use this method, but implement paywalls logic by adding your paywall configuration in Apphud Dashboard > Product Hub > Paywalls.
     
     - Note: You shouldn't call this method at app launch, because Apphud SDK automatically fetches products during initialization. Only use this method as a fallback.
     */
    @objc public static func refreshStoreKitProducts(_ callback: (([SKProduct], Error?) -> Void)?) {
        ApphudInternal.shared.refreshStoreKitProductsWithCallback(callback: callback)
    }

    /**
     Returns array of `SKProduct` objects that you added in Apphud > Product Hub > Products.
     
     Note that this method will return `nil` if products are not yet fetched from the App Store. You should observe for `Apphud.didFetchProductsNotification()` notification or implement  `apphudDidFetchStoreKitProducts` delegate method or set `productsDidFetchCallback` block.
     
     - Important: Best practise is not to use this method, but implement paywalls logic by adding your paywall configuration in Apphud Dashboard > Product Hub > Paywalls.
     */
    @objc(storeKitProducts)
    public static var products: [SKProduct]? {
        guard ApphudStoreKitWrapper.shared.products.count > 0 else {
            return nil
        }
        return ApphudStoreKitWrapper.shared.products
    }

    /**
     Returns `SKProduct` object by product identifier. Note that you have to add this product identifier in Apphud Dashboard > Product Hub > Products.
     
     - Note: Will return `nil` if product is not yet fetched from the App Store.
     
     - Important: Best practise is not to use this method, but implement paywalls logic by adding your paywall configuration in Apphud Dashboard > Product Hub > Paywalls.
     */
    @objc public static func product(productIdentifier: String) -> SKProduct? {
        return ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == productIdentifier})
    }

    /**
     Initiates purchase of `ApphudProduct` object from your `ApphudPaywall` and automatically submits App Store Receipt to Apphud.
     
     - parameter product: Required. `ApphudProduct` object from your `ApphudPaywall`. You must first configure paywalls in Apphud Dashboard > Product Hub > Paywalls.
     
     - parameter callback: Optional. Returns `ApphudPurchaseResult` object.
     
     - Note: You are not required to purchase product using Apphud SDK methods. You can purchase subscription or any in-app purchase using your own code. App Store receipt will be sent to Apphud anyway.
     */
    @objc(purchaseApphudProduct:callback:)
    public static func purchase(_ product: ApphudProduct, callback: ((ApphudPurchaseResult) -> Void)?) {
        ApphudInternal.shared.purchase(productId: product.productId, product: product, validate: true, callback: callback)
    }

    /**
     Deprecated. Purchase product by product identifier. Use this method if you don't use Apphud Paywalls logic.
     
     - parameter product: Required. Identifier of the product that user wants to purchase. If you don't use Apphud paywalls, you can use this purchase method.
     
     - parameter callback: Optional. Returns `ApphudPurchaseResult` object.
     
     - Note: A/B Experiments feature will not work if you purchase products by your own code or by using this method. If you want to use A/B experiments, you must use Apphud Paywalls and initiate purchase of  `ApphudProduct` object instead.
     
     - Important: Best practise is not to use this method, but implement paywalls logic by adding your paywall configuration in Apphud Dashboard > Product Hub > Paywalls.
     */
    @objc(purchaseById:callback:)
    public static func purchase(_ productId: String, callback: ((ApphudPurchaseResult) -> Void)?) {
        ApphudInternal.shared.purchase(productId: productId, product: nil, validate: true, callback: callback)
    }

    /**
     Purchases product and automatically submits App Store Receipt to Apphud. This method doesn't wait until Apphud validates receipt from Apple and immediately returns transaction object. This method may be useful if you don't care about receipt validation in callback.
     
     - parameter productId: Required. Identifier of the product that user wants to purchase.
     - parameter callback: Optional. Returns `ApphudPurchaseResult` object.
     
     - Note: When using this method properties `subscription` and `nonRenewingPurchase` in `ApphudPurchaseResult` will always be `nil` !
     */
    @objc(purchaseWithoutValidationById:callback:)
    public static func purchaseWithoutValidation(_ productId: String, callback: ((ApphudPurchaseResult) -> Void)?) {
        ApphudInternal.shared.purchase(productId: productId, product: nil, validate: false, callback: callback)
    }

    /**
     Purchases subscription (promotional) offer and automatically submits App Store Receipt to Apphud.
     
     - parameter product: Required. This is an `SKProduct` object that user wants to purchase.
     - parameter discountID: Required. This is a `SKProductDiscount` Identifier String object that you would like to apply.
     - parameter callback: Optional. Returns `ApphudPurchaseResult` object.
     
     - Note: This method automatically sends in-app purchase receipt to Apphud, so you don't need to call `submitReceipt` method.
     */
    @available(iOS 12.2, *)
    @objc public static func purchasePromo(_ product: SKProduct, discountID: String, _ callback: ((ApphudPurchaseResult) -> Void)?) {
        let apphudProduct = ApphudInternal.shared.allAvailableProducts.first(where: { $0.productId == product.productIdentifier })
        ApphudInternal.shared.purchasePromo(skProduct: product, apphudProduct: apphudProduct, discountID: discountID, callback: callback)
    }

    /**
     Displays an offer code redemption sheet.
     */
    @available(iOS 14.0, *)
    @objc public static func presentOfferCodeRedemptionSheet() {
        ApphudStoreKitWrapper.shared.presentOfferCodeSheet()
    }

    // MARK: - Promotionals
    /**
     You can grant free promotional subscription to user. Returns `true` in a callback if promotional was granted. After this `hasActiveSubscription()` method will return `true`.
     
     - parameter daysCount: Required. Number of days of free premium usage. For lifetime promotionals just pass extremely high value, like 10000.
     - parameter productId: Optional*. Recommended. Product Id of promotional subscription. See __Note__ message above for details.
     - parameter permissionGroup: Optional*. Permission Group of promotional subscription. Use this parameter in case you have multiple permission groups. See __Note__ message above for details.
     - parameter callback: Optional. Returns `true` if promotional subscription was granted.
     
     - Note: You should pass either `productId` (recommended) or `permissionGroup` OR both parameters `nil`. Sending both `productId` and `permissionGroup` parameters will result in `productId` being used. Docs](https://docs.apphud.com/getting-started/product-hub/products)
     */
    @objc public static func grantPromotional(daysCount: Int, productId: String?, permissionGroup: ApphudGroup?, callback: ApphudBoolCallback?) {
        ApphudInternal.shared.grantPromotional(daysCount, permissionGroup, productId: productId, callback: callback)
    }

    // MARK: - Paywall logs
    
    /**
     Logs "Paywall Shown" event that will be used in Apphud Dashboard.
     
     - Note: For more information  - [Paywall Shown Event Documentation](https://docs.apphud.com/events/events#paywall-shown)
     */
    @objc public static func paywallShown(_ paywall: ApphudPaywall) {
        ApphudLoggerService.shared.paywallShown(paywall.id)
    }
    
    /**
     Logs "Paywall Closed" event that will be used in Apphud Dashboard.
     
     - Note: For more information  - [Paywall Closed Event Documentation](https://docs.apphud.com/events/events#paywall-closed)
     */
    @objc public static func paywallClosed(_ paywall: ApphudPaywall) {
        ApphudLoggerService.shared.paywallClosed(paywall.id)
    }

    // MARK: - Handle Purchases

    /**
     Returns `true` if user has active subscription or non renewing purchase (lifetime).
     
     Use this method to determine whether or not user has active premium access. If you have consumable purchases, this method won't operate correctly, because Apphud SDK doesn't differ consumables from non-consumables.
     
     - Important: You should not use this method if you have consumable in-app purchases, like coin packs.
     */
    @objc public static func hasPremiumAccess() -> Bool {
        hasActiveSubscription() || (nonRenewingPurchases()?.first(where: { $0.isActive() }) != nil)
    }
    
    /**
     Returns `true` if user has active subscription.
     
     Use this method to determine whether or not user has active premium subscription.
     
     - Important: Note that if you have lifetime (nonconsumable) or consumable purchases, you must use another ``Apphud/isNonRenewingPurchaseActive(productIdentifier:)`` method.
     */
    @objc public static func hasActiveSubscription() -> Bool {
        Apphud.subscriptions()?.first(where: { $0.isActive() == true }) != nil
    }

    /**
     Permission groups configured in Apphud dashboard > Product Hub > Products. Groups are cached on device.
     
     - Important: Note that this method may be `nil` at first launch of the app.
     */
    @objc public static var permissionGroups: [ApphudGroup] {
        ApphudInternal.shared.productGroups
    }

    /**
     Returns subscription object that current user has ever purchased. Subscriptions are cached on device.
     
     You should check `Apphud.hasActiveSubscription()` method or `subscription.isActive()` value to determine whether or not to unlock premium functionality to the user.
     
     If you have more than one subscription group in your app, use `subscriptions()` method and get `isActive` value for your desired subscription.
     
     - Note: If returned object is not `nil`, it doesn't mean that subsription is active.
     */
    @objc public static func subscription() -> ApphudSubscription? {
        return ApphudInternal.shared.currentUser?.subscriptions.first
    }

    /**
     Returns an array of all subscriptions that this user has ever purchased. Subscriptions are cached on device.
     
     Use this method if you have more than one subsription group in your app.
     */
    @objc public static func subscriptions() -> [ApphudSubscription]? {
        return ApphudInternal.shared.currentUser?.subscriptions
    }

    /**
     Returns an array of all standard in-app purchases (consumables, nonconsumables or nonrenewing subscriptions) that this user has ever purchased. Purchases are cached on device. This array is sorted by purchase date. Apphud only tracks consumables if they were purchased after integrating Apphud SDK.
     */
    @objc public static func nonRenewingPurchases() -> [ApphudNonRenewingPurchase]? {
        return ApphudInternal.shared.currentUser?.purchases
    }

    /**
     Returns `true` if current user has purchased standard in-app purchase with given product identifier. Returns `false` if this product is refunded or never purchased. Includes consumables, nonconsumables or non-renewing subscriptions. Apphud only tracks consumables if they were purchased after integrating Apphud SDK.
     
     - Note: Purchases are sorted by purchase date, so it returns Bool value for the most recent purchase by given product identifier.
     */
    @objc public static func isNonRenewingPurchaseActive(productIdentifier: String) -> Bool {
        return ApphudInternal.shared.currentUser?.purchases.first(where: {$0.productId == productIdentifier})?.isActive() ?? false
    }

    /**
     Basically the same as restoring purchases.
     */
    @objc public static func validateReceipt(callback: @escaping ([ApphudSubscription]?, [ApphudNonRenewingPurchase]?, Error?) -> Void) {
        Apphud.restorePurchases(callback: callback)
    }

    /**
     Implements `Restore Purchases` mechanism. Basically it just sends current App Store Receipt to Apphud and returns subscriptions info.
     
     - parameter callback: Required. Returns array of subscription (or subscriptions in case you have more than one subscription group), array of standard in-app purchases and an error. All of three parameters are optional.
     
     - Note: Even if callback returns some subscription, it doesn't mean that subscription is active. You should check `subscription.isActive()` value.
     */     
    @objc public static func restorePurchases(callback: @escaping ([ApphudSubscription]?, [ApphudNonRenewingPurchase]?, Error?) -> Void) {
        ApphudInternal.shared.restorePurchases(callback: callback)
    }

    /**
     If you already have a live app with paying users and you want Apphud to track their purchases, you should import their App Store receipts into Apphud. Call this method at launch of your app for your paying users. This method should be used only to migrate existing paying users that are not yet tracked by Apphud.
     
     Example:
     
     ```swift
        // hasPurchases - is your own boolean value indicating that current user is paying user.
        if hasPurchases {
            Apphud.migratePurchasesIfNeeded { _, _, _ in}
        }
     ```
     
     - Note: You can remove this method after a some period of time, i.e. when you are sure that all paying users are already synced with Apphud.
     */
    @objc public static func migratePurchasesIfNeeded(callback: @escaping ([ApphudSubscription]?, [ApphudNonRenewingPurchase]?, Error?) -> Void) {
        if apphudShouldMigrate() {
            ApphudInternal.shared.restorePurchases { (subscriptions, purchases, error) in
                if error == nil {
                    apphudDidMigrate()
                }
                callback(subscriptions, purchases, error)
            }
        }
    }

    /**
     Returns base64 encoded App Store receipt string, if available.
     */
    @objc public static func appStoreReceipt() -> String? {
        apphudReceiptDataString()
    }

    /**
     Fetches raw receipt info in a wrapped `ApphudReceipt` model class. This might be useful to get `original_application_version` value.
     */
    @objc public static func fetchRawReceiptInfo(_ completion: @escaping (ApphudReceipt?) -> Void) {
        ApphudReceipt.getRawReceipt(completion: completion)
    }

    // MARK: - User Properties

    /**

     Set custom user property. Value must be one of: `Int`, `Float`, `Double`, `Bool`, `String`, `NSNumber`, `NSString`, `NSNull`, `nil`.

     Example:
     ```swift
     // use built-in property key
     Apphud.setUserProperty(key: .email, value: "user4@example.com", setOnce: true)
     // use custom property key
     Apphud.setUserProperty(key: .init("custom_test_property_1"), value: 0.5)
     ```
     #### You can use several built-in keys with their value types:
     
     `.email`: User email. Value must be String.

     `.name`: User name. Value must be String.

     `.phone`: User phone number. Value must be String.

     `.age`: User age. Value must be Int.

     `.gender`: User gender. Value must be one of: "male", "female", "other".

     `.cohort`: User install cohort. Value must be String.

     - parameter key: Required. Initialize class with custom string or using built-in keys. See example above.
     - parameter value: Required/Optional. Pass `nil` or `NSNull` to remove given property from Apphud.
     - parameter setOnce: Optional. Pass `true` to make this property non-updatable.

     */

    @objc public static func setUserProperty(key: ApphudUserPropertyKey, value: Any?, setOnce: Bool = false) {
        ApphudInternal.shared.setUserProperty(key: key, value: value, setOnce: setOnce, increment: false)
    }

    /**

    Increment custom user property. Value must be one of: `Int`, `Float`, `Double` or `NSNumber`.

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
     Presents Apphud screen that was delayed for presentation, i.e. `false` was returned in `apphudShouldShowScreen` delegate method.
     */
    @objc public static func showPendingScreen() {
        return ApphudRulesManager.shared.showPendingScreen()
    }

    /**
        Screen view controller that is pending for presentation. This is the screen that is triggered by your pending Rule. You can use `showPendingScreen` method or present this controller manually.
     */
    @objc public static func pendingScreenController() -> UIViewController? {
        return ApphudRulesManager.shared.pendingController
    }
    /**
        Rule with a screen that was delayed for presentation.
     */
    @objc public static func pendingRule() -> ApphudRule? {
        return ApphudRulesManager.shared.pendingRule()
    }
    #endif
    // MARK: - Push Notifications

    /**
     Submit device push token to Apphud.
     - parameter token: Push token in Data class.
     - parameter callback: Returns true if successfully sent.
    */
    @objc public static func submitPushNotificationsToken(token: Data, callback: ApphudBoolCallback?) {
        ApphudInternal.shared.submitPushNotificationsToken(token: token, callback: callback)
    }

    /**
     Handles push notification payload. Use this method to handle incoming Rules. Apphud handles only push notifications that were created by Apphud.
     - parameter apsInfo: Payload of push notification.
     
     Returns `true` if push notification was successfully handled by Apphud.
     */
    #if os(iOS)
    @discardableResult @objc public static func handlePushNotification(apsInfo: [AnyHashable: Any]) -> Bool {
        return ApphudRulesManager.shared.handleNotification(apsInfo)
    }
    #endif
    // MARK: - Attribution

    /**
     Submit Advertising Identifier (IDFA) to Apphud. This is used to properly match user with attribution platforms (AppsFlyer, Facebook, etc.)
     */
    @objc public static func setAdvertisingIdentifier(_ idfa: String) {
        ApphudInternal.shared.advertisingIdentifier = idfa
    }

    /**
     Submit attribution data to Apphud from your attribution network provider.
     - parameter data: Required. Attribution dictionary.
     - parameter provider: Required. Attribution provider name. Available values: .appsFlyer. Will be added more soon.
     - parameter identifier: Optional. Identifier that matches Apphud and Attrubution provider. Required for AppsFlyer. 
     - parameter callback: Optional. Returns true if successfully sent.
     */
    @objc public static func addAttribution(data: [AnyHashable: Any]?, from provider: ApphudAttributionProvider, identifer: String? = nil, callback: ApphudBoolCallback?) {
        ApphudInternal.shared.addAttribution(data: data, from: provider, identifer: identifer, callback: callback)
    }

    // MARK: - Eligibility Checks

    /**
        Checks whether the given product is eligible for purchasing introductory offer (`free trial`, `pay as you go` or `pay up front` modes).
     
        New and returning customers are eligible for introductory offers including free trials as follows:
     
        * New subscribers are always eligible.
     
        * Lapsed subscribers who renew are eligible if they haven't previously used an introductory offer for the given product (or any product within the same subscription group).
     
        - parameter product: Required. This is an `SKProduct` object for which you want to check intro offers eligibility.
        - parameter callback: Returns true if product is eligible for purchasing introductory offer.
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
        Checks whether the given product is eligible for purchasing any of it's promotional offers.
     
        Only customers who already purchased subscription are eligible for promotional offer for the given product (or any product within the same subscription group).
        
        - parameter product: Required. This is an `SKProduct` object for which you want to check promo offers eligibility.
        - parameter callback: Returns true if product is eligible for purchasing promotional any of it's promotional offers.
        */    

    @available(iOS 12.2, *)
    @objc public static func checkEligibilityForPromotionalOffer(product: SKProduct, callback: @escaping ApphudBoolCallback) {
        ApphudInternal.shared.checkEligibilitiesForPromotionalOffers(products: [product]) { result in
            callback(result[product.productIdentifier] ?? false)
        }
    }

    /**
     Checks promotional offers eligibility for multiple products at once.
     
     - parameter products: Required. This is an array of `SKProduct` objects for which you want to check promo offers eligibilities.
     - parameter callback: Returns dictionary with product identifiers and boolean values.
     */ 
    @available(iOS 12.2, *)
    @objc public static func checkEligibilitiesForPromotionalOffers(products: [SKProduct], callback: @escaping ApphudEligibilityCallback) {
        ApphudInternal.shared.checkEligibilitiesForPromotionalOffers(products: products, callback: callback)
    }

    /**
        Checks introductory offers eligibility for multiple products at once.
     
        - parameter products: Required. This is an array of `SKProduct` objects for which you want to check introductory offers eligibilities.
        - parameter callback: Returns dictionary with product identifiers and boolean values.
     */ 
    @objc public static func checkEligibilitiesForIntroductoryOffers(products: [SKProduct], callback: @escaping ApphudEligibilityCallback) {
        ApphudInternal.shared.checkEligibilitiesForIntroductoryOffers(products: products, callback: callback)
    }

    // MARK: - Other

    /**
        Enables debug logs. You should call this method before SDK initialization.
     */
    @objc public static func enableDebugLogs() {
        ApphudUtils.enableDebugLogs()
    }

    /**
        Returns `true` if current build is running on sumulator or Debug/TestFlight modes. Returns `false` if current build is App Store build.
     */
    @objc public static func isSandbox() -> Bool {
        return apphudIsSandbox()
    }
}
