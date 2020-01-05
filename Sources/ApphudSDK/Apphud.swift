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
     
        This method is called when any subscription in an array has been changed (for example, status changed from `trial` to `expired`).
     
        In most cases you don't need this method because you already have completion blocks in `purchase`, `purchasePromo` and `submitReceipt` methods. However this method may be useful to detect whether subscription was purchased in Apphud's puchase screen.
     */
    @objc optional func apphudSubscriptionsUpdated(_ subscriptions: [ApphudSubscription])
    
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
     
        You can use this delegate method or observe for `Apphud.didFetchProductsNotification()` notification. 
     */
    @objc optional func apphudDidFetchStoreKitProducts(_ products: [SKProduct])
}

@objc public protocol ApphudUIDelegate {
    
    /**
        You can return `false` to this delegate method if you don't want Apphud Screen to be displayed at this time.
     
        If you returned `false`, this controller will be accessible in `Apphud.pendingScreen()` method. You will be able to present it manually later.
     */
    @objc optional func apphudShouldShowScreen(controller: UIViewController) -> Bool
    
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
     
     You can observe for this notification or implement `apphudDidFetchStoreKitProducts` delegate method.
     */
    @objc public static func didFetchProductsNotification() -> Notification.Name {
        return Notification.Name("ApphudDidFetchProductsNotification")
    }
    
    /**
     Returns array of `SKProduct` objects that you added in Apphud. 
     
     Note that this method will return `nil` if products are not yet fetched. You should observe for `Apphud.didFetchProductsNotification()` notification or implement  `apphudDidFetchStoreKitProducts` delegate method.
     */
    @objc public static func products() -> [SKProduct]? {
        guard ApphudStoreKitWrapper.shared.products.count > 0 else {
            return nil
        }
        return ApphudStoreKitWrapper.shared.products
    }
    
    /**
     Returns `SKProduct` object by product identifier. Note that you have to add this product identifier in Apphud.
     
     Will retun `nil` if product is not yet fetched from StoreKit.
     */
    @objc public static func product(productIdentifier : String) -> SKProduct? {
        return ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == productIdentifier})
    }
    
    /**
     Purchases product and automatically submits App Store Receipt to Apphud.
     
     __Note__: This method automatically sends in-app purchase receipt to Apphud, so you don't need to call `submitReceipt` method.    
     
     - parameter product: Required. This is an `SKProduct` object that user wants to purchase.
     - parameter callback: Optional. Returns `ApphudSubscription` object if succeeded and an optional error otherwise.
     */
    @objc public static func purchase(_ product: SKProduct, callback: ((ApphudSubscription?, Error?) -> Void)?){
        ApphudInternal.shared.purchase(product: product, callback: callback)
    }

    /**
        Purchases subscription (promotional) offer and automatically submits App Store Receipt to Apphud. 
     
        __Note__: This method automatically sends in-app purchase receipt to Apphud, so you don't need to call `submitReceipt` method.    
     
        - parameter product: Required. This is an `SKProduct` object that user wants to purchase.
        - parameter discountID: Required. This is a `SKProductDiscount` Identifier String object that you would like to apply.
        - parameter callback: Optional. Returns `ApphudSubscription` object if succeeded and an optional error otherwise.
     */
    @available(iOS 12.2, *)
    @objc public static func purchasePromo(_ product: SKProduct, discountID: String, _ callback: ((ApphudSubscription?, Error?) -> Void)?){
        ApphudInternal.shared.purchasePromo(product: product, discountID: discountID, callback: callback)
    }
    
    /**
         __Deprecated__. Starting now Apphud SDK automatically tracks all your in-app purchases and submits App Store receipt to Apphud. You can safely remove this method from your code. If you were using callback, you can use `apphudSubscriptionsUpdated` delegate method instead.
     */
    @available(*, deprecated, message: "Starting now Apphud SDK automatically tracks all your in-app purchases and submits App Store receipt to Apphud. You can safely remove this method from your code. If you were using callback, you can use `apphudSubscriptionsUpdated` delegate method instead.")
    @objc public static func submitReceipt(_ productIdentifier : String, _ callback : ((ApphudSubscription?, Error?) -> Void)?) {
        ApphudInternal.shared.submitReceipt(productId: productIdentifier, callback: callback)        
    }
    
    //MARK:- Handle Subscriptions
    
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
     Implements `Restore Purchases` mechanism. Basically it just sends current App Store Receipt to Apphud and returns subscriptions info.
     
     __Note__: Even if callback returns some subscription, it doesn't mean that subscription is active. You should check `subscription.isActive()` value.
     
     You should use this method in 2 cases:
        * Upon tap on `Restore Purchases` button in your UI.
        * To migrate existing subsribers to Apphud. If you want your current subscribers to be tracked in Apphud, call this method once at the first launch.   
     - parameter callback: Required. Returns array of subscription (or subscriptions in case you more than one subscription group). Returns nil if user never purchased a subscription.
     */     
    @objc public static func restoreSubscriptions(callback: @escaping ([ApphudSubscription]?) -> Void) {
        ApphudInternal.shared.restoreSubscriptions(callback: callback)
    }
    
    /**
     If you already have a live app with paying users and you want Apphud to track their subscriptions, you should import their App Store receipts into Apphud. Call this method at launch of your app for your paying users. This method should be used only to migrate existing paying users that are not yet tracked by Apphud.
     
     Example:
     
        ````
        // hasPurchases - is your own boolean value indicating that current user is paying user.
        if hasPurchases {
            Apphud.migrateSubscriptionsIfNeeded {_ in}
        }
        ````
     
    __Note__: You can remove this method after a some period of time, i.e. when you are sure that all paying users are already synced with Apphud.
     */
    @objc public static func migrateSubscriptionsIfNeeded(callback: @escaping ([ApphudSubscription]?) -> Void) {
        if apphudShouldMigrate() {
            ApphudInternal.shared.restoreSubscriptions { subscriptions in
                apphudDidMigrate()
                callback(subscriptions)
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
