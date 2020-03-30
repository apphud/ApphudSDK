//
//  Apphud.swift
//  Apphud
//
//  Created by ren6 on 28/04/2019.
//  Copyright © 2019 Softeam Inc. All rights reserved.
//

import UIKit
import StoreKit
import UserNotifications

public typealias ApphudEligibilityCallback = (([String : Bool]) -> Void)
public typealias ApphudBoolCallback = ((Bool) -> Void)

// MARK:- Delegate

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
        Returns array of `SKProduct` objects after they are fetched from StoreKit. Note that you have to add all product identifiers in Apphud.
     
        You can use `productsDidFetchCallback` callback or observe for `didFetchProductsNotification()` or implement `apphudDidFetchStoreKitProducts` delegate method. Use whatever you like most. 
     */
    @objc optional func apphudDidFetchStoreKitProducts(_ products: [SKProduct])
    
    /**
     Implements mechanism of purchasing In-App Purchase initiated directly from the App Store page. Return your callback block in this delegate method, it will be called when purchase is finished.
     */
    @objc optional func apphudShouldStartAppStoreDirectPurchase(_ product: SKProduct) -> ((ApphudPurchaseResult) -> Void)
}

@objc public protocol ApphudUIDelegate {
    
    /**
        You can return `false` to ignore this rule. You should only do this if you want to handle your rules by yourself. Default implementation is `true`.
     */
    @objc optional func apphudShouldPerformRule(rule: ApphudRule) -> Bool
    
    /**
        You can return `false` to this delegate method if you want to delay Apphud Screen presentation.
     
        Controller will be kept in memory until you present it via `Apphud.showPendingScreen()` method. If you don't want to show screen at all, you should check `apphudShouldPerformRule` delegate method.
     */
    @objc optional func apphudShouldShowScreen(screenName: String) -> Bool
    
    /**
        Return `UIViewController` instance from which you want to present given Apphud controller. If you don't implement this method, then top visible viewcontroller from key window will be used.
     
        __Note__: This delegate method is recommended for implementation when you have multiple windows in your app, because Apphud SDK may have issues while presenting screens in this case. 
     */
    @objc optional func apphudParentViewController(controller: UIViewController) -> UIViewController
    
    /**
     Pass your own modal presentation style to Apphud Screens. This is useful since iOS 13 presents in page sheet style by default. 
     
     To get full screen style you should pass `.fullScreen` or `.overFullScreen`.
     */
    @objc optional func apphudScreenPresentationStyle(controller: UIViewController) -> UIModalPresentationStyle

    /**
     Called when user tapped on purchase button in Apphud purchase screen.
    */
    @objc optional func apphudWillPurchase(product: SKProduct, offerID: String?, screenName: String)
    
    /**
     Called when user successfully purchased product in Apphud purchase screen.
    */
    @objc optional func apphudDidPurchase(product: SKProduct, offerID: String?, screenName: String)
    
    /**
     Called when purchase failed in Apphud purchase screen.
     
     See error code for details. For example, `.paymentCancelled` error code is when user canceled the purchase by himself.
    */
    @objc optional func apphudDidFailPurchase(product: SKProduct, offerID: String?, errorCode: SKError.Code, screenName: String)
    
    /**
     Notifies that Apphud Screen did dismiss
    */
    @objc optional func apphudDidDismissScreen(controller: UIViewController)
}

/// List of available attribution providers
@objc public enum ApphudAttributionProvider : Int {
    case appsFlyer
    case adjust
    case appleSearchAds
    case facebook
    /**
     Branch is implemented and doesn't require any additional code from Apphud SDK 
     More details: https://docs.apphud.com/integrations/attribution/branch
     
     case branch
     */
}

//MARK:- Initialization

@available(iOS 11.2, *)
final public class Apphud: NSObject {
    
    /**
     Initializes Apphud SDK. You should call it during app launch.
     
     - parameter apiKey: Required. Your api key.
     - parameter userID: Optional. You can provide your own unique user identifier. If nil passed then UUID will be generated instead.
     */
    @objc public static func start(apiKey: String, userID: String? = nil) {
        ApphudInternal.shared.initialize(apiKey: apiKey, userID: userID)
    }
    
    /**
     Updates user ID value 
     - parameter userID: Required. New user ID value.
     */
    @objc public static func updateUserID(_ userID : String) {
        ApphudInternal.shared.updateUserID(userID: userID)
    }
    
    /**
     Returns current userID that identifies user across his multiple devices. 
     
     This value may change in runtime, see `apphudDidChangeUserID(_ userID : String)` for details.
     */
    @objc public static func userID() -> String {
        return ApphudInternal.shared.currentUserID
    }
    
    /**
     Set a delegate.
     - parameter delegate: Required. Any ApphudDelegate conformable object.
     */
    @objc public static func setDelegate(_ delegate : ApphudDelegate) {
        ApphudInternal.shared.delegate = delegate
    }
      
    /**
     Set a UI delegate.
     - parameter delegate: Required. Any ApphudUIDelegate conformable object.
     */
    @objc public static func setUIDelegate(_ delegate : ApphudUIDelegate) {
        ApphudInternal.shared.uiDelegate = delegate
    }
    
    //MARK:- Make Purchase
    
    /**
     This notification is sent when SKProducts are fetched from StoreKit. Note that you have to add all product identifiers in Apphud.
     
     You can use `productsDidFetchCallback` callback or observe for `didFetchProductsNotification()` or implement `apphudDidFetchStoreKitProducts` delegate method. Use whatever you like most.
     */
    @objc public static func didFetchProductsNotification() -> Notification.Name {
        return Notification.Name("ApphudDidFetchProductsNotification")
    }
    
    /**
    This callback is called when SKProducts are fetched from StoreKit. Note that you have to add all product identifiers in Apphud.
    
    You can use `productsDidFetchCallback` callback or observe for `didFetchProductsNotification()` or implement `apphudDidFetchStoreKitProducts` delegate method. Use whatever you like most.
    */
    @objc public static func productsDidFetchCallback(_ callback: @escaping ([SKProduct]) -> Void) {
        ApphudStoreKitWrapper.shared.customProductsFetchedBlock = callback
    }
    
    /**
    Refreshes SKProducts from the App Store. You have to add all product identifiers in Apphud. 
     
     __Note__: You shouldn't call this method at app launch, because Apphud SDK automatically fetches products during initialization. Only use this method as a fallback.
     */
    @objc public static func refreshStoreKitProducts(_ callback: (([SKProduct]) -> Void)?) {
        ApphudInternal.shared.refreshStoreKitProductsWithCallback(callback: callback)
    }
    
    /**
     Returns array of `SKProduct` objects that you added in Apphud. 
     
     Note that this method will return `nil` if products are not yet fetched. You should observe for `Apphud.didFetchProductsNotification()` notification or implement  `apphudDidFetchStoreKitProducts` delegate method or set `productsDidFetchCallback` block.
     */
    @objc public static func products() -> [SKProduct]? {
        guard ApphudStoreKitWrapper.shared.products.count > 0 else {
            return nil
        }
        return ApphudStoreKitWrapper.shared.products
    }
    
    /**
     Returns `SKProduct` object by product identifier. Note that you have to add this product identifier in Apphud.
     
     Will return `nil` if product is not yet fetched from StoreKit.
     */
    @objc public static func product(productIdentifier : String) -> SKProduct? {
        return ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == productIdentifier})
    }
    
    /**
     Purchases product and automatically submits App Store Receipt to Apphud.
     
     __Note__:  You are not required to purchase product using Apphud SDK methods. You can purchase subscription or any in-app purchase using your own code. App Store receipt will be sent to Apphud anyway.
     
     - parameter product: Required. This is an `SKProduct` object that user wants to purchase. 
     - parameter callback: Optional. Returns `ApphudPurchaseResult` object.
     */
    @objc public static func purchase(_ product: SKProduct, callback: ((ApphudPurchaseResult) -> Void)?){
        ApphudInternal.shared.purchase(product: product, callback: callback)
    }

    /**
    Purchases product and automatically submits App Store Receipt to Apphud. This method doesn't wait until Apphud validates receipt from Apple and immediately returns transaction object. This method may be useful if you don't care about receipt validation in callback. 
    
     __Note__:  You are not required to purchase product using Apphud SDK methods. You can purchase subscription or any in-app purchase using your own code. App Store receipt will be sent to Apphud anyway.
     
    - parameter product: Required. This is an `SKProduct` object that user wants to purchase.
    - parameter callback: Optional. Returns optional `SKPaymentTransaction` object and an optional error.
    */
    @objc public static func purchaseWithoutValidation(_ product: SKProduct,  callback: ((SKPaymentTransaction, Error?) -> Void)?){
        ApphudInternal.shared.purchaseWithoutValidation(product: product, callback: callback)
    }
    
    /**
        Purchases subscription (promotional) offer and automatically submits App Store Receipt to Apphud. 
     
        __Note__: This method automatically sends in-app purchase receipt to Apphud, so you don't need to call `submitReceipt` method.    
     
        - parameter product: Required. This is an `SKProduct` object that user wants to purchase.
        - parameter discountID: Required. This is a `SKProductDiscount` Identifier String object that you would like to apply.
        - parameter callback: Optional. Returns `ApphudPurchaseResult` object.
     */
    @available(iOS 12.2, *)
    @objc public static func purchasePromo(_ product: SKProduct, discountID: String, _ callback: ((ApphudPurchaseResult) -> Void)?){
        ApphudInternal.shared.purchasePromo(product: product, discountID: discountID, callback: callback)
    }
    
    //MARK:- Handle Purchases
    
    /**
        Returns true if user has active subscription.
     
        Use this method to determine whether or not to unlock premium functionality to the user.
     */
    @objc public static func hasActiveSubscription() -> Bool {
        return Apphud.subscription()?.isActive() ?? false
    }
    
    /**
     Returns subscription object that current user has ever purchased. Subscriptions are cached on device.
     
     __Note__: If returned object is not nil, it doesn't mean that subsription is active.
     You should check `Apphud.hasActiveSubscription()` method or `subscription.isActive()` value to determine whether or not to unlock premium functionality to the user.
     
     If you have more than one subscription group in your app, use `subscriptions()` method and get `isActive` value for your desired subscription.
     
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
     
     __Note__: Purchases are sorted by purchase date, so it returns Bool value for the most recent purchase by given product identifier.
     */
    @objc public static func isNonRenewingPurchaseActive(productIdentifier : String) -> Bool {
        return ApphudInternal.shared.currentUser?.purchases.first(where: {$0.productId == productIdentifier})?.isActive() ?? false
    }
    
    /**
     Implements `Restore Purchases` mechanism. Basically it just sends current App Store Receipt to Apphud and returns subscriptions info.
     
     __Note__: Even if callback returns some subscription, it doesn't mean that subscription is active. You should check `subscription.isActive()` value.
     
     You should use this method in 2 cases:
        * Upon tap on `Restore Purchases` button in your UI.
        * To migrate existing subsribers to Apphud. If you want your current subscribers to be tracked in Apphud, call this method once at the first launch.   
     - parameter callback: Required. Returns array of subscription (or subscriptions in case you have more than one subscription group), array of standard in-app purchases and an error. All of three parameters are optional.
     */     
    @objc public static func restorePurchases(callback: @escaping ([ApphudSubscription]?, [ApphudNonRenewingPurchase]?, Error?) -> Void) {
        ApphudInternal.shared.restorePurchases(callback: callback)
    }
    
    /**
     If you already have a live app with paying users and you want Apphud to track their purchases, you should import their App Store receipts into Apphud. Call this method at launch of your app for your paying users. This method should be used only to migrate existing paying users that are not yet tracked by Apphud.
     
     Example:
     
        ````
        // hasPurchases - is your own boolean value indicating that current user is paying user.
        if hasPurchases {
            Apphud.migratePurchasesIfNeeded { _, _, _ in}
        }
        ````
     
    __Note__: You can remove this method after a some period of time, i.e. when you are sure that all paying users are already synced with Apphud.
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
    
    //MARK:- Rules & Screens Methods
    
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
    
    //MARK:- Push Notifications
    
    /**
     Submit device push token to Apphud.
     - parameter token: Push token in Data class.
     - parameter callback: Returns true if successfully sent.
    */
    @objc public static func submitPushNotificationsToken(token: Data, callback: ApphudBoolCallback?){
        ApphudInternal.shared.submitPushNotificationsToken(token: token, callback: callback)
    }
    
    /**
     Handles push notification payload. Apphud handles only push notifications that were created by Apphud.
     - parameter apsInfo: Payload of push notification.
     
     Returns true if push notification was handled by Apphud.
     */
    @discardableResult @objc public static func handlePushNotification(apsInfo: [AnyHashable : Any]) -> Bool{
        return ApphudRulesManager.shared.handleNotification(apsInfo)
    }
    
    //MARK:- Attribution
    
    /**
     Submit attribution data to Apphud from your attribution network provider.
     - parameter data: Required. Attribution dictionary.
     - parameter provider: Required. Attribution provider name. Available values: .appsFlyer. Will be added more soon.
     - parameter identifier: Optional. Identifier that matches Apphud and Attrubution provider. Required for AppsFlyer. 
     - parameter callback: Optional. Returns true if successfully sent.
     */
    @objc public static func addAttribution(data: [AnyHashable : Any], from provider: ApphudAttributionProvider, identifer: String? = nil, callback: ApphudBoolCallback?){
        ApphudInternal.shared.addAttribution(data: data, from: provider, identifer: identifer, callback: callback)
    }
    
    //MARK:- Eligibility Checks
    
    /**
        Checks whether the given product is eligible for purchasing any of it's promotional offers.
     
        Only customers who already purchased subscription are eligible for promotional offer for the given product (or any product within the same subscription group).
        
        - parameter product: Required. This is an `SKProduct` object for which you want to check promo offers eligibility.
        - parameter callback: Returns true if product is eligible for purchasing promotional any of it's promotional offers.
        */    
    
    @available(iOS 12.2, *)
    @objc public static func checkEligibilityForPromotionalOffer(product: SKProduct, callback: @escaping ApphudBoolCallback){
        ApphudInternal.shared.checkEligibilitiesForPromotionalOffers(products: [product]) { result in
            callback(result[product.productIdentifier] ?? false)
        }
    }
    
    /**
        Checks whether the given product is eligible for purchasing introductory offer (`free trial`, `pay as you go` or `pay up front` modes).
     
        New and returning customers are eligible for introductory offers including free trials as follows:
     
        * New subscribers are always eligible.
     
        * Lapsed subscribers who renew are eligible if they haven't previously used an introductory offer for the given product (or any product within the same subscription group).
     
        - parameter product: Required. This is an `SKProduct` object for which you want to check promo offers eligibility.
        - parameter callback: Returns true if product is eligible for purchasing promotional offer.
     */  
    @objc public static func checkEligibilityForIntroductoryOffer(product: SKProduct, callback: @escaping ApphudBoolCallback){
        ApphudInternal.shared.checkEligibilitiesForIntroductoryOffers(products: [product]) { result in
            callback(result[product.productIdentifier] ?? true)
        }
    }
    
    /**
     Checks promotional offers eligibility for multiple products at once.
     
     - parameter products: Required. This is an array of `SKProduct` objects for which you want to check promo offers eligibilities.
     - parameter callback: Returns dictionary with product identifiers and boolean values.
     */ 
    @available(iOS 12.2, *)
    @objc public static func checkEligibilitiesForPromotionalOffers(products: [SKProduct], callback: @escaping ApphudEligibilityCallback){
        ApphudInternal.shared.checkEligibilitiesForPromotionalOffers(products: products, callback: callback)
    }
    
    /**
        Checks introductory offers eligibility for multiple products at once.
     
        - parameter products: Required. This is an array of `SKProduct` objects for which you want to check introductory offers eligibilities.
        - parameter callback: Returns dictionary with product identifiers and boolean values.
     */ 
    @objc public static func checkEligibilitiesForIntroductoryOffers(products: [SKProduct], callback: @escaping ApphudEligibilityCallback){
        ApphudInternal.shared.checkEligibilitiesForIntroductoryOffers(products: products, callback: callback)
    }
    
    //MARK:- Other
    
    /**
     Enables debug logs. Better to call this method before SDK initialization.
     */
    @objc public static func enableDebugLogs(){
        ApphudUtils.enableDebugLogs()
    }
    
    /**
     Automatically finishes all pending transactions. By default, Apphud SDK only finishes transactions, that were started by Apphud SDK, i.e. by calling  any of `Apphud.purchase..()` methods.
    
     However, when you debug in-app purchases and/or change Apple ID too often, some transactions may stay in the queue (for example, if you broke execution until transaction is finished). And these transactions will try to finish at every next app launch. In this case you may see a system alert prompting to enter your Apple ID password. To fix this annoying issue, you can add this method.
     
     You may also use this method in production if you don't care about handling pending transactions, for example, downloading Apple hosted content.
     For more information read "Finish the transaction" paragraph here: https://developer.apple.com/library/archive/technotes/tn2387/_index.html
     
     __Note__: Only use this method if you know what you are doing. Must be called before Apphud SDK initialization.
     */
    @objc public static func setFinishAllTransactions(){
        ApphudUtils.shared.finishTransactions = true
    }
    
    /**
        This method must be called before SDK initialization. Apphud will send all subscription events of current user to your test analytics, if test api keys are set in integrations dashboard.
     */
    @objc public static func setIntegrationsTestMode(){
        ApphudInternal.shared.isIntegrationsTestMode = true
    }
    
    /**
     Opt out of IDFA collection. Currently we collect IDFA to match users between Apphud and attribution platforms (AppsFlyer, Branch). If you don't use and not planning to use such services, you can call this method.
     
     __Note__: This method must be called before Apphud SDK initialization.
     */
    @objc public static func disableIDFACollection(){
        ApphudUtils.shared.optOutOfIDFACollection = true
    }
    
    /**
    Not yet available for public use.
    */
    #if DEBUG
    @objc public static func start(apiKey: String, userID : String? = nil, deviceID : String? = nil) {
        ApphudInternal.shared.initialize(apiKey: apiKey, userID: userID, deviceIdentifier: deviceID)
    }
    #endif
}
