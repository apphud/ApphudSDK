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

@objc public protocol ApphudDelegate {
    
    /**
     Called when subscriptions information has been updated. 
     
     This delegate method is called in 2 cases:
     
     * When subscriptions are restored.
     * When subscription state has been changed. For example, if state has changed from trial to regular.
     
     __Note__: This delegate method is not called when user has made a purchase. A callback block is called instead.
     
     This doesn't mean that user has active subscriptions, this only means that application has just fetched the latest information about his subscriptions and something has changed.
     */
    @objc optional func apphudSubscriptionsUpdated(_ subscriptions : [ApphudSubscription])
    
    /**
     Called when user ID has been changed.
     
     This delegate method is called in 2 cases:
     
     * When Apphud has merged two users into a single user (for example, after user has restored purchases from his another device).
     After App Store receipt has been sent to Apphud, server tries to find the same receipt in the database.
     If the same App Store receipt has been found, Apphud merges two users into a single user with two devices and then returns an original userID. 
     
     __Note__: Only users who have ever purchased a subscription and sent their App Store receipt to Apphud can be merged.  
     
     * After manual call of `updateUserID(userID : String)` method. 
     */
    @objc optional func apphudDidChangeUserID(_ userID : String)    
}

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
    Not yet available to public.
    */
    #if DEBUG
    @objc public static func start(apiKey: String, userID : String? = nil, deviceID : String? = nil) {
        ApphudInternal.shared.initialize(apiKey: apiKey, userID: userID, deviceIdentifier: deviceID)
    }
    #endif
    
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
     Purchases product and automatically submits App Store Receipt to Apphud.
     
     __Note__: This method automatically sends in-app purchase receipt to Apphud, so you don't need to call `submitReceipt` method.    
     
     - parameter product: Required. This is an `SKProduct` object that user wants to purchase.
     - parameter callback: Optional. Returns `ApphudSubscription` object if succeeded and an optional error otherwise.
     */
    @objc public static func purchase(product: SKProduct, callback: ((ApphudSubscription?, Error?) -> Void)?){
        ApphudInternal.shared.purchase(product: product, callback: callback)
    }

    /**
        Purchases promotional offer and automatically submits App Store Receipt to Apphud.
     
        __Note__: This method automatically sends in-app purchase receipt to Apphud, so you don't need to call `submitReceipt` method.    
     
        - parameter product: Required. This is an `SKProduct` object that user wants to purchase.
        - parameter discountID: Required. This is a `SKProductDiscount` Identifier String object that you would like to apply.
        - parameter callback: Optional. Returns `ApphudSubscription` object if succeeded and an optional error otherwise.
     */
    @available(iOS 12.2, *)
    @objc public static func purchasePromo(product: SKProduct, discountID: String, callback: ((ApphudSubscription?, Error?) -> Void)?){
        ApphudInternal.shared.purchasePromo(product: product, discountID: discountID, callback: callback)
    }
    /**
         Use this method if you have your own purchase mechanism and you want only to submit App Store Receipt to Apphud.
     
         - parameter productIdentifier: Required. This is an identifier string of the product that user has just purchased.
         - parameter callback: Optional. Returns `ApphudSubscription` object if succeeded and an optional error otherwise.  
     */
    @objc public static func submitReceipt(_ productIdentifier : String, callback : ((ApphudSubscription?, Error?) -> Void)?) {
        ApphudInternal.shared.submitReceipt(productId: productIdentifier, callback: callback)        
    }
    
    /**
        Checks whether the given product is eligible for purchasing any of it's promotional offers.
     
        Only customers who already purchased subscription are eligible for promotional offer for the given product (or any product within the same subscription group).
        
        - parameter product: Required. This is an `SKProduct` object for which you want to check promo offers eligibility.
        - parameter callback: Returns true if product is eligible for purchasing promotional any of it's promotional offers.
        */    
    
    @available(iOS 12.2, *)
    @objc public static func checkEligibilityForPromotionalOffer(product: SKProduct, callback: @escaping (Bool) -> Void){
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
    @objc public static func checkEligibilityForIntroductoryOffer(product: SKProduct, callback: @escaping (Bool) -> Void){
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
    
    /**
     Returns subscription object that current user has ever purchased. Subscriptions are cached on device.
     
     __Note__: If returned object is not nil, it doesn't mean that subsription is active.
     You should check subscription's `isActive` property to determine whether or not to unlock premium functionality to the user.
     
     Example:   
     
     ````
     let active = Apphud.purchasedSubscription()?.isActive ?? false
     ````
     
     If you have more than one subscription group in your app, use `subscriptions()` method and get `isActive` value for your desired subscription.
     
     */
    @objc public static func purchasedSubscription() -> ApphudSubscription? {
        return ApphudInternal.shared.currentUser?.subscriptions?.first
    }
    
    /**
     Returns an array of all auto-renewable subscriptions that this user has ever purchased.  Subscriptions are cached on device.
     
     This is only needed if you have more than one subsription group in your app.
     */
    @objc public static func purchasedSubscriptions() -> [ApphudSubscription]? {
        return ApphudInternal.shared.currentUser?.subscriptions
    }
    
    /**
     Returns a subscription for a given product identifier. Returns nil if subscription has never been purchased for a given product identifier.
     - parameter productID: Required. Product identifier of a subscription.
     */
    @objc public static func purchasedSubscriptionFor(productID: String) -> ApphudSubscription? {
        return Apphud.purchasedSubscriptions()?.first(where: {$0.productId == productID})
    }
    
    /**
     Restores subscriptions associated with current App Store account.
     
     If App Store receipt exists on device, SDK submits it to Apphud server and returns the latest subscriptions info in a delegate method. 
     If App Store receipt is missing on device then refresh receipt request is sent and operation retries. 
     
     If the app was downloaded from the App Store there is always a receipt so refresh receipt won't be called.
     It also means that password prompt dialog won't be displayed to the user with this restore mechanism.
     
     However, you shouldn't call this method at every launch. There are 2 main reasons why you should use this method:
     * If you already have users and you want to submit their App Store receipts to Apphud to sync subscriptions data.
     * As an action for "restore purchases" button at your subscription purchase screen or somewhere else. Restore purchases button is needed if you don't have a system that identifies each user.
     
     This function doesn't mean that it will return active subscriptions; it just means that the latest information will be fetched from our server.
     */     
    @objc public static func restoreSubscriptions() {
        ApphudInternal.shared.submitAppStoreReceipt(allowsReceiptRefresh: true)
    }
    
    /**
     Submit device push token to Apphud.
     - parameter token: Push token in Data class.
     - parameter callback: Returns true if successfully sent.
    */
    @objc public static func submitPushNotificationsToken(token: Data, callback: @escaping (Bool) -> Void){
        ApphudInternal.shared.submitPushNotificationsToken(token: token, callback: callback)
    }
    
    /**
     Handles push notification payload. Apphud handles only push notifications that were created by Apphud.
     - parameter apsInfo: Payload of push notification.
     
     Returns true if push notification was handled by Apphud.
     */
    @discardableResult @objc public static func handlePushNotification(apsInfo: [AnyHashable : Any]) -> Bool{
        return ApphudNotificationsHandler.shared.handleNotification(apsInfo)
    }
    
    /**
     Enables debug logs. Better to call this method before SDK initialization.
     */
    @objc public static func enableDebugLogs(){
        ApphudUtils.enableDebugLogs()
    }
    
}
