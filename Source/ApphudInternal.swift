//
//  ApphudInternal.swift
//  subscriptionstest
//
//  Created by Renat on 01/07/2019.
//  Copyright © 2019 apphud. All rights reserved.
//

import Foundation
import AdSupport
import StoreKit

let sdk_version = "0.6.1"

final class ApphudInternal {
    
    fileprivate let requiresReceiptSubmissionKey = "requiresReceiptSubmissionKey"
    
    static let shared = ApphudInternal()
    var delegate : ApphudDelegate?
    var currentUser : ApphudUser?
    
    var currentDeviceID : String!
    var currentUserID : String!
    fileprivate var isSubmittingReceipt : Bool = false
    
    private var lastCheckDate = Date()
    
    var httpClient : ApphudHttpClient!
    fileprivate var requires_currency_update = false
        
    fileprivate var userRegisteredCallbacks = [ApphudVoidCallback]()
    fileprivate var productGroupsFetchedCallbacks = [ApphudVoidCallback]()
    
    private var productsGroupsMap : [String : String]?
        
    internal func initialize(apiKey: String, userID : String?, deviceIdentifier : String? = nil){
        
        apphudLog("Started Apphud SDK (\(sdk_version))", forceDisplay: true)
        
        ApphudStoreKitWrapper.shared.setupObserver()
        
        var deviceID = ApphudKeychain.loadDeviceID() 
        
        if deviceIdentifier != nil {
            deviceID = deviceIdentifier
        }
        
        if deviceID == nil {
            deviceID = ApphudKeychain.generateUUID()
            ApphudKeychain.saveDeviceID(deviceID: deviceID!)
        }
        
        self.currentDeviceID = deviceID!
        
        self.httpClient = ApphudHttpClient.shared 
        self.httpClient.apiKey = apiKey
        
        self.currentUser = ApphudUser.fromCache()
        
        if userID != nil {
            self.currentUserID = userID!
        } else if let existingUserID = self.currentUser?.user_id {
            self.currentUserID = existingUserID
        } else {
            self.currentUserID = ApphudKeychain.generateUUID()
        }
        
        self.productsGroupsMap = fromUserDefaultsCache(key: "productsGroupsMap")
        
        continueToRegisteringUser()
    }

    private func continueToRegisteringUser(){
        createOrGetUser { success in
            if success {
                apphudLog("User successfully registered")
                self.performAllUserRegisteredBlocks()                
                self.continueToUpdateProducts()
                self.listenForAwakeNotification()
                self.checkForUnreadNotifications()
            } else {                
                self.userRegisteredCallbacks.removeAll()
            }
        }
    }
    
    private func continueToUpdateProducts(){
        self.getProducts(callback: { (productsGroupsMap) in
            // perform even if productsGroupsMap is nil or empty
            self.performAllProductGroupsFetchedCallbacks()
            
            guard productsGroupsMap?.keys.count ?? 0 > 0 else {
                return
            }
            
            self.productsGroupsMap = productsGroupsMap
            
            apphudLog("Products groups fetched: \(self.productsGroupsMap as AnyObject)")
            
            toUserDefaultsCache(dictionary: self.productsGroupsMap!, key: "productsGroupsMap")
            
            self.continueToFetchStoreKitProducts()
        })
    }
    
    private func continueToFetchStoreKitProducts(){
        ApphudStoreKitWrapper.shared.fetchProducts(identifiers: Set(self.productsGroupsMap!.keys)) { (skproducts) in
            self.updateUserCurrencyIfNeeded(priceLocale: skproducts.first?.priceLocale)
            self.submitProducts(products: skproducts) { (result3, response3, error3) in
                if result3 {
                    apphudLog("Products prices successfully submitted")
                } else {
                    apphudLog("Failed to submit products prices, error:\(error3?.localizedDescription ?? "")")
                }
            }
            
        }
    }
    
    private func listenForAwakeNotification(){
        NotificationCenter.default.addObserver(self, selector: #selector(handleDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
    }
    
    @objc private func handleDidBecomeActive(){
        
        #if DEBUG
        let minCheckInterval :Double = 10
        #else
        let minCheckInterval :Double = 5*60
        #endif
        
        if Date().timeIntervalSince(lastCheckDate) >  minCheckInterval{
            self.checkForUnreadNotifications()
            self.refreshCurrentUser()
        }
    }
    
    @discardableResult private func parseUser(_ dict : [String : Any]?) -> Bool{
        
        guard let dataDict = dict?["data"] as? [String : Any] else {
            return false
        }
        guard let userDict = dataDict["results"] as? [String : Any] else {
            return false
        }
        let currency = userDict["currency"] 
        if currency is NSNull {
            requires_currency_update = true            
        } 
        
        let oldStates = self.currentUser?.subscriptionsStates()
        
        self.currentUser = ApphudUser(dictionary: userDict)
        
        let newStates = self.currentUser?.subscriptionsStates()
        
        ApphudUser.toCache(userDict)
        
        checkUserID(tellDelegate: true)
        
        /**
         If user previously didn't have subscriptions or subscriptions states don't match, or subscription product identifiers don't match
         */
        if oldStates != newStates && self.currentUser?.subscriptions != nil {
            return true
        } else {
            return false
        }
    }
        
    private func checkUserID(tellDelegate : Bool){
        guard let userID = self.currentUser?.user_id else {return}        
        if self.currentUserID != userID {
            self.currentUserID = userID
            if tellDelegate {
                self.delegate?.apphudDidChangeUserID?(userID)
            }
        }
    }
    
    // MARK: Helper
    /// Returns false if current user is not yet registered, block is added to array and will be performed later.
    @discardableResult internal func performWhenUserRegistered(callback : @escaping ApphudVoidCallback) -> Bool{
        if currentUser != nil {
            callback()
            return true
        } else {
            userRegisteredCallbacks.append(callback)
            return false
        }
    }
    
    private func performAllUserRegisteredBlocks(){
        for block in userRegisteredCallbacks {
            apphudLog("Performing scheduled block..")
            block()
        }
        if userRegisteredCallbacks.count > 0 {
            apphudLog("All scheduled blocks performed, removing..")
            userRegisteredCallbacks.removeAll()
        }
    }
    
    /// Returns false if products groups map dictionary not yet received, block is added to array and will be performed later.
    @discardableResult internal func performWhenProductGroupsFetched(callback : @escaping ApphudVoidCallback) -> Bool{
        if self.productsGroupsMap != nil {
            callback()
            return true
        } else {
            productGroupsFetchedCallbacks.append(callback)
            return false
        }
    }
    
    private func performAllProductGroupsFetchedCallbacks(){
        for block in productGroupsFetchedCallbacks {
            apphudLog("Performing scheduled block..")
            block()
        }
        if productGroupsFetchedCallbacks.count > 0 {
            apphudLog("All scheduled blocks performed, removing..")
            productGroupsFetchedCallbacks.removeAll()
        }
    }
    
    // MARK: API Requests
    
    private func createOrGetUser(callback: @escaping (Bool) -> Void) {
        
        var params : [String : String] = ["device_id" : self.currentDeviceID]
        if self.currentUserID != nil {
            params["user_id"] = self.currentUserID!
        }
        
        let deviceParams = currentDeviceParameters()
        params.merge(deviceParams) { (current, new) in current}
        
        httpClient.startRequest(path: "customers", params: params, method: .post) { (result, response, error) in
            
            var hasSubscriptionChanges = false
            if result {
                hasSubscriptionChanges = self.parseUser(response)
            }
            
            let finalResult = result && self.currentUser != nil
            
            if finalResult {
                if hasSubscriptionChanges {
                    self.delegate?.apphudSubscriptionsUpdated?(self.currentUser!.subscriptions!)
                }
                if UserDefaults.standard.bool(forKey: self.requiresReceiptSubmissionKey) {
                    self.submitAppStoreReceipt(allowsReceiptRefresh: false)
                }
            }
            
            if error != nil {
                apphudLog("Failed to register or get user, error:\(error!.localizedDescription)")
            }
            
            callback(finalResult)
        }        
    }
    
    private func updateUserCurrencyIfNeeded(priceLocale : Locale?){
        guard requires_currency_update else { return }
        guard let priceLocale = priceLocale else { return }
        guard let countryCode = priceLocale.regionCode else { return }
        guard let currencyCode = priceLocale.currencyCode else { return }
        
        var params : [String : String] = ["country_code" : countryCode,
                                          "currency_code" : currencyCode]
        if self.currentUserID != nil {
            params["user_id"] = self.currentUserID!
        }
        params.merge(currentDeviceParameters()) { (current, new) in current}
        
        updateUser(fields: params) { (result, response, error) in
            if result {
                self.requires_currency_update = false
                self.parseUser(response)
            }
        }
    }
    
    internal func updateUserID(userID : String) {    
        let exist = performWhenUserRegistered { 
            self.updateUser(fields: ["user_id" : userID]) { (result, response, error) in
                if result {
                    self.requires_currency_update = false
                    self.parseUser(response)
                }
            }            
        }
        if !exist {
            apphudLog("Tried to make update user id: \(userID) request when user is not yet registered, addind to schedule..")
        }
    }
    
    private func updateUser(fields: [String : Any], callback: @escaping ApphudBoolDictionaryCallback){
        var params = currentDeviceParameters() as [String : Any]
        params.merge(fields) { (current, new) in current}
        params["device_id"] = self.currentDeviceID
        
        httpClient.startRequest(path: "customers", params: params, method: .post, callback: callback)
    }
    
    private func refreshCurrentUser(){
        createOrGetUser { _ in }         
    }
    
    private func getProducts(callback: @escaping (([String : String]?) -> Void)) {
        
        httpClient.startRequest(path: "products", params: nil, method: .get) { (result, response, error) in
            if result, let dataDict = response?["data"] as? [String : Any],
                let productsArray = dataDict["results"] as? [[String : Any]] {  
                
                var map = [String : String]()
                
                for product in productsArray {
                    let productID = product["product_id"] as! String
                    let groupID = (product["group_id"] as? String) ?? ""
                    map[productID] = groupID
                }
                callback(map)
            } else {
                callback(nil)
            }
        }
    }
    
    private func submitProducts(products: [SKProduct], callback : @escaping ApphudBoolDictionaryCallback) {
        var array = [[String : Any]]()
        for product in products {
            let productParams : [String : Any] = product.submittableParameters()            
            array.append(productParams)
        }
        
        let params = ["products" : array] as [String : Any]
        
        httpClient.startRequest(path: "products", params: params, method: .put, callback: callback)        
    }    
    
    internal func submitReceipt(productId : String, callback : ((ApphudSubscription?, Error?) -> Void)?) {
        guard let receiptString = receiptDataString() else { 
            ApphudStoreKitWrapper.shared.refreshReceipt()
            callback?(nil, ApphudError.error(message: "Receipt not found on device, refreshing."))
            return 
        }
        
        let exist = performWhenUserRegistered { 
            self.submitReceipt(receiptString: receiptString, notifyDelegate: false) { error in
                callback?(Apphud.purchasedSubscriptionFor(productID: productId), error)
            }            
        }
        if !exist {
            apphudLog("Tried to make submitReceipt: \(productId) request when user is not yet registered, addind to schedule..")
        }
    }
    
    internal func submitAppStoreReceipt(allowsReceiptRefresh : Bool) {
        guard let receiptString = receiptDataString() else {
            if allowsReceiptRefresh {
                apphudLog("App Store receipt is missing on device, will refresh first then retry")
                ApphudStoreKitWrapper.shared.refreshReceipt()
            } else {
                apphudLog("App Store receipt is missing on device and couldn't be refreshed.", forceDisplay: true)
            }
            return 
        }
        
        let exist = performWhenUserRegistered { 
            self.submitReceipt(receiptString: receiptString, notifyDelegate: true, callback: nil)
        }
        if !exist {
            apphudLog("Tried to make restore allows: \(allowsReceiptRefresh) request when user is not yet registered, addind to schedule..")
        }
    }
    
    private func submitReceipt(receiptString : String, notifyDelegate : Bool, callback : ((Error?) -> Void)?) {
        
        if isSubmittingReceipt {return}
        isSubmittingReceipt = true
        
        #if DEBUG
        let environment = "sandbox"
        #else 
        let environment = "production"
        #endif
        
        let params : [String : String] = ["device_id" : self.currentDeviceID,
                                          "receipt_data" : receiptString,
                                          "environment" : environment]
        
        UserDefaults.standard.set(true, forKey: requiresReceiptSubmissionKey)
        
        httpClient.startRequest(path: "subscriptions", params: params, method: .post) { (result, response, error) in        
            
            self.isSubmittingReceipt = false
            
            if result {
                UserDefaults.standard.set(false, forKey: self.requiresReceiptSubmissionKey)
                UserDefaults.standard.synchronize()
                if self.parseUser(response) {
                    // do not call delegate method only purchase, use callback instead
                    if notifyDelegate {
                        self.delegate?.apphudSubscriptionsUpdated?(self.currentUser!.subscriptions!)
                    }
                }
            }
            
            callback?(error)
        }
    }
    
    internal func purchase(product: SKProduct, callback: ((ApphudSubscription?, Error?) -> Void)?){
        ApphudStoreKitWrapper.shared.purchase(product: product) { transaction in
            if transaction.transactionState == .purchased {
                self.submitReceipt(productId: product.productIdentifier, callback: callback)
            } else {
                callback?(nil, transaction.error)
            }
        }
    }    
    
    @available(iOS 12.2, *)
    internal func purchasePromo(product: SKProduct, discountID: String, callback: ((ApphudSubscription?, Error?) -> Void)?){
        self.signPromoOffer(productID: product.productIdentifier, discountID: discountID) { (paymentDiscount, error) in
            if let paymentDiscount = paymentDiscount {                
                ApphudInternal.shared.purchasePromo(product: product, discount: paymentDiscount, callback: callback)
            } else {
                callback?(nil, ApphudError.error(message: "Could not sign offer id: \(discountID), product id: \(product.productIdentifier)"))
            }
        }
    }
    
    @available(iOS 12.2, *)
    internal func purchasePromo(product: SKProduct, discount: SKPaymentDiscount, callback: ((ApphudSubscription?, Error?) -> Void)?){
        ApphudStoreKitWrapper.shared.purchase(product: product, discount: discount) { transaction in
            if transaction.transactionState == .purchased {
                self.submitReceipt(productId: product.productIdentifier, callback: callback)
            } else {
                callback?(nil, transaction.error)
            }
        }
    }
    
    @available(iOS 12.2, *)
    internal func signPromoOffer(productID: String, discountID: String, callback: ((SKPaymentDiscount?, Error?) -> Void)?){
        let params : [String : Any] = ["product_id" : productID, "offer_id" : discountID, ]
        httpClient.startRequest(path: "sign_offer", params: params, method: .post) { (result, dict, error) in
            if result, let responseDict = dict, let dataDict = responseDict["data"] as? [String : Any], let resultsDict = dataDict["results"] as? [String : Any]{
                
                let signatureData = resultsDict["data"] as? [String : Any]
                let uuid = UUID(uuidString: signatureData?["nonce"] as? String ?? "")                
                let signature = signatureData?["signature"] as? String
                let timestamp = signatureData?["timestamp"] as? NSNumber
                let keyID = resultsDict["key_id"] as? String
                
                if signature != nil && uuid != nil && timestamp != nil && keyID != nil {
                    let paymentDiscount = SKPaymentDiscount(identifier: discountID, keyIdentifier: keyID!, nonce: uuid!, signature: signature!, timestamp: timestamp!)
                    callback?(paymentDiscount, nil)
                    return
                }
            }
            
            let error = ApphudError.error(message: "Could not sign promo offer id: \(discountID), product id: \(productID)")
            callback?(nil, error)
        }
    }
    
    /// Promo offers eligibility
    
    @available(iOS 12.2, *)
    internal func checkEligibilitiesForPromotionalOffers(products: [SKProduct], callback: @escaping ApphudEligibilityCallback){
        
        let result = performWhenUserRegistered {
            
            apphudLog("User registered, check promo eligibility")
            
            let didSendReceiptForPromoEligibility = "ReceiptForPromoSent"
            
            // not found subscriptions, try to restore and try again
            if self.currentUser?.subscriptions?.count ?? 0 == 0 && !UserDefaults.standard.bool(forKey: didSendReceiptForPromoEligibility){
                if let receiptString = receiptDataString() {
                    apphudLog("Restoring subscriptions for promo eligibility check")
                    self.submitReceipt(receiptString: receiptString, notifyDelegate: false, callback: { error in
                        UserDefaults.standard.set(true, forKey: didSendReceiptForPromoEligibility)
                        self._checkPromoEligibilitiesForRegisteredUser(products: products, callback: callback)
                    })
                } else {
                    apphudLog("Receipt not found for promo eligibility check, exiting")
                    // receipt not found and subscriptions not purchased, impossible to determine eligibility
                    // this should never not happen on production, because receipt always exists
                    var response = [String : Bool]() 
                    for product in products {
                        response[product.productIdentifier] = false // cannot purchase offer by default
                    }
                    callback(response)
                }
            } else {
                apphudLog("Has purchased subscriptions or has checked receipt for promo eligibility")
                self._checkPromoEligibilitiesForRegisteredUser(products: products, callback: callback)
            }
        }
        if !result {
            apphudLog("Tried to check promo eligibility, but user not registered, adding to schedule")
        }
    }
    
    @available(iOS 12.2, *)
    private func _checkPromoEligibilitiesForRegisteredUser(products: [SKProduct], callback: @escaping ApphudEligibilityCallback) {
        
        var response = [String : Bool]()
        for product in products {
            response[product.productIdentifier] = false
        }
        
        let result = self.performWhenProductGroupsFetched {
            
            apphudLog("Products fetched, check promo eligibility")
            
            for subscription in self.currentUser?.subscriptions ?? [] {
                for product in products {
                    let purchasedGroupId = self.productsGroupsMap?[subscription.productId]
                    let givenGroupId = self.productsGroupsMap?[product.productIdentifier]
                    if (subscription.productId == product.productIdentifier) || 
                        (purchasedGroupId != nil && purchasedGroupId == givenGroupId) {
                        // if the same product or in the same group
                        response[product.productIdentifier] = true
                        // do not break, check all products
                    }
                }
            }
            apphudLog("Finished promo checking, response: \(response as AnyObject)")
            callback(response)
        }
        if !result {
            apphudLog("Tried to check promo eligibility, but products not fetched, adding to schedule")
        }
    }
    
    /// Checks introductory offers eligibility (includes free trial, pay as you go or pay up front)
    @available(iOS 11.2, *)
    internal func checkEligibilitiesForIntroductoryOffers(products: [SKProduct], callback: @escaping ApphudEligibilityCallback){

        let result = performWhenUserRegistered {
            
            apphudLog("User registered, check intro eligibility")
            
            // not found subscriptions, try to restore and try again
            
            let didSendReceiptForIntroEligibility = "ReceiptForIntroSent"
            
            if self.currentUser?.subscriptions?.count ?? 0 == 0 && !UserDefaults.standard.bool(forKey: didSendReceiptForIntroEligibility){
                if let receiptString = receiptDataString() {
                    apphudLog("Restoring subscriptions for intro eligibility check")
                    self.submitReceipt(receiptString: receiptString, notifyDelegate: false, callback: { error in
                        UserDefaults.standard.set(true, forKey: didSendReceiptForIntroEligibility)
                        self._checkIntroEligibilitiesForRegisteredUser(products: products, callback: callback)
                    })
                } else {
                    apphudLog("Receipt not found for intro eligibility check, exiting")
                    // receipt not found and subscriptions not purchased, impossible to determine eligibility
                    // this should never not happen on production, because receipt always exists
                    var response = [String : Bool]() 
                    for product in products {
                        response[product.productIdentifier] = true // can purchase intro by default
                    }
                    callback(response)
                }
            } else {
                apphudLog("Has purchased subscriptions or has checked receipt for intro eligibility")
                self._checkIntroEligibilitiesForRegisteredUser(products: products, callback: callback)
            }
        } 
        if !result {
            apphudLog("Tried to check intro eligibility, but user not registered, adding to schedule")
        }
    }
    
    @available(iOS 11.2, *)
    private func _checkIntroEligibilitiesForRegisteredUser(products: [SKProduct], callback: @escaping ApphudEligibilityCallback) {
        
        var response = [String : Bool]()
        for product in products {
            response[product.productIdentifier] = true
        }
        
        let result = self.performWhenProductGroupsFetched {
            
            apphudLog("Products fetched, check intro eligibility")
            
            for subscription in self.currentUser?.subscriptions ?? [] {
                for product in products {
                    let purchasedGroupId = self.productsGroupsMap?[subscription.productId]
                    let givenGroupId = self.productsGroupsMap?[product.productIdentifier]
                    
                    if subscription.productId == product.productIdentifier ||
                        (purchasedGroupId == givenGroupId && givenGroupId != nil) {
                        // if purchased, then this subscription is eligible for intro only if not used intro and status expired
                        let eligible = !subscription.isIntroductoryActivated && subscription.status == .expired
                        response[product.productIdentifier] = eligible
                        // do not break, check all products
                    }
                }
            }
            apphudLog("Finished intro checking, response: \(response as AnyObject)")
            callback(response)
        }
        
        if !result {
            apphudLog("Tried to check intro eligibility, but products not fetched, adding to schedule")
        }
    }
    
    internal func submitPushNotificationsToken(token: Data, callback: @escaping (Bool) -> Void){
        performWhenUserRegistered {
            let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
            let params : [String : String] = ["device_id" : self.currentDeviceID, "push_token" : tokenString]
            self.httpClient.startRequest(path: "customers/push_token", params: params, method: .put) { (result, response, error) in
                callback(result)
            }             
        }
    }
    
    internal func trackRuleEvent(ruleID: String, params: [String : String], callback: @escaping ()->Void){
        
        let result = performWhenUserRegistered {
            let final_params : [String : String] = ["device_id" : self.currentDeviceID].merging(params, uniquingKeysWith: {(current,_) in current})
            self.httpClient.startRequest(path: "rules/\(ruleID)/events", params: final_params, method: .post) { (result, response, error) in
                callback()
            }            
        }
        if !result {
            apphudLog("Tried to trackRuleEvent, but user not yet registered, adding to schedule")
        }
    }
    
    internal func getRule(ruleID: String, callback: @escaping (ApphudRule?) -> Void){
        
        let result = performWhenUserRegistered {
            let params = ["device_id": self.currentDeviceID] as [String : String]
            
            self.httpClient.startRequest(path: "rules/\(ruleID)", params: params, method: .get) { (result, response, error) in
                if result, let dataDict = response?["data"] as? [String : Any],
                    let ruleDict = dataDict["results"] as? [String : Any] {
                    callback(ApphudRule(dictionary: ruleDict))
                } else {
                    callback(nil)
                }
            } 
        }
        if !result {
            apphudLog("Tried to getRule \(ruleID), but user not yet registered, adding to schedule")
        }
    }
    
    internal func checkForUnreadNotifications(){
        performWhenUserRegistered {
            self.lastCheckDate = Date()
            let params = ["device_id": self.currentDeviceID] as [String : String]
            self.httpClient.startRequest(path: "notifications/unread", params: params, method: .get, callback: { (result, response, error) in
                if  result, 
                    let dataDict = response?["data"] as? [String : Any],
                    let notifArray = dataDict["results"] as? [[String : Any]], 
                    let ruleDict = notifArray.first?["rule"] as? [String : Any] {
                    let rule = ApphudRule(dictionary: ruleDict)
                    ApphudInquiryController.show(rule: rule)
                }
            })
        }
    }
}

