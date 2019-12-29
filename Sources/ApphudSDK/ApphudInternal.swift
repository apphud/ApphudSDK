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

let sdk_version = "0.8"

@available(iOS 11.2, *)
final class ApphudInternal {
    
    fileprivate let requiresReceiptSubmissionKey = "requiresReceiptSubmissionKey"
    
    static let shared = ApphudInternal()
    var delegate : ApphudDelegate?
    var uiDelegate : ApphudUIDelegate?
    var currentUser : ApphudUser?
    
    var isIntegrationsTestMode = false
    
    var currentDeviceID : String = ""
    var currentUserID : String = ""
    fileprivate var isSubmittingReceipt : Bool = false
    
    private var lastCheckDate = Date()
    
    var httpClient : ApphudHttpClient!
        
    private var addedObservers = false
    
    fileprivate var userRegisteredCallbacks = [ApphudVoidCallback]()
    fileprivate var productGroupsFetchedCallbacks = [ApphudVoidCallback]()
    
    private var productsGroupsMap : [String : String]?
        
    private var submitReceiptCallback : ((Error?) -> Void)?
    
    private var restoreSubscriptionCallback : (([ApphudSubscription]?) -> Void)?
    
    private var allowInitialize = true
    
    internal func initialize(apiKey: String, userID : String?, deviceIdentifier : String? = nil){
        
        apphudLog("Started Apphud SDK (\(sdk_version))", forceDisplay: true)
        
        if !allowInitialize {return}
        allowInitialize = false
        
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
            
            self.allowInitialize = !success
            
            if success {
                apphudLog("User successfully registered")
                self.performAllUserRegisteredBlocks()                
                self.setupObservers()
                self.checkForUnreadNotifications()
            } else {                
                self.userRegisteredCallbacks.removeAll()
            }
            // try to continue anyway, because maybe already has cached data, try to fetch storekit products
            self.continueToFetchProducts()
        }
    }
    
    private func continueToFetchProducts(){
        self.getProducts(callback: { (productsGroupsMap) in
            // perform even if productsGroupsMap is nil or empty
            self.performAllProductGroupsFetchedCallbacks()
            
            if productsGroupsMap?.keys.count ?? 0 > 0 {
                self.productsGroupsMap = productsGroupsMap
                apphudLog("Products groups fetched: \(self.productsGroupsMap as AnyObject)")
                toUserDefaultsCache(dictionary: self.productsGroupsMap!, key: "productsGroupsMap")                
            }
            // continue to fetch storekit products anyway
            self.continueToFetchStoreKitProducts()
        })
    }
    
    private func continueToFetchStoreKitProducts(){
        
        guard self.productsGroupsMap?.keys.count ?? 0 > 0 else {
            return
        }
            
        ApphudStoreKitWrapper.shared.fetchProducts(identifiers: Set(self.productsGroupsMap!.keys)) { (skproducts) in
            self.updateUserCurrencyIfNeeded(priceLocale: skproducts.first?.priceLocale)
            if skproducts.count > 0 {
                self.continueToUpdateProductsPrices(products: skproducts)
            }
        }
    }
    
    private func continueToUpdateProductsPrices(products : [SKProduct]){
        self.submitProducts(products: products, callback: nil)
    }
    
    private func setupObservers(){
        if !addedObservers {
            NotificationCenter.default.addObserver(self, selector: #selector(handleDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
            addedObservers = true
        }
    }
    
    @objc private func handleDidBecomeActive(){
        
        let minCheckInterval :Double = 30
        
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
        
        self.updateUser(fields: ["user_id" : self.currentUserID]) { (result, response, error) in
            
            var hasSubscriptionChanges = false
            if result {
                hasSubscriptionChanges = self.parseUser(response)
            }
            
            let finalResult = result && self.currentUser != nil
            
            if finalResult {
                if hasSubscriptionChanges {
                    self.delegate?.apphudSubscriptionsUpdated?(self.currentUser!.subscriptions)
                }
                if UserDefaults.standard.bool(forKey: self.requiresReceiptSubmissionKey) {
                    self.submitReceiptRestore(allowsReceiptRefresh: false)
                }
            }
            
            if error != nil {
                apphudLog("Failed to register or get user, error:\(error!.localizedDescription)")
            }
            
            callback(finalResult)
        }        
    }
    
    private func updateUserCurrencyIfNeeded(priceLocale : Locale?){
        guard let priceLocale = priceLocale else { return }
        guard let countryCode = priceLocale.regionCode else { return }
        guard let currencyCode = priceLocale.currencyCode else { return }
        
        if countryCode == self.currentUser?.countryCode && currencyCode == self.currentUser?.currencyCode {return}

        var params : [String : String] = ["country_code" : countryCode,
                                          "currency_code" : currencyCode,
                                          "user_id" : self.currentUserID]       
        
        params.merge(currentDeviceParameters()) { (current, new) in current}
        
        updateUser(fields: params) { (result, response, error) in
            if result {
                self.parseUser(response)
            }
        }
    }
    
    internal func updateUserID(userID : String) {    
        let exist = performWhenUserRegistered { 
            self.updateUser(fields: ["user_id" : userID]) { (result, response, error) in
                if result {
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
        params["is_debug"] = self.isIntegrationsTestMode
        // do not automatically pass currentUserID here,because we have separate method updateUserID
        httpClient.startRequest(path: "customers", params: params, method: .post, callback: callback)
    }
    
    private func refreshCurrentUser(){
        createOrGetUser { _ in 
            self.lastCheckDate = Date()
        }         
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
    
    private func submitProducts(products: [SKProduct], callback: ApphudBoolDictionaryCallback?) {
        var array = [[String : Any]]()
        for product in products {
            let productParams : [String : Any] = product.submittableParameters()            
            array.append(productParams)
        }
        
        let params = ["products" : array] as [String : Any]
        
        httpClient.startRequest(path: "products", params: params, method: .put, callback: callback)        
    }    
    
    //MARK:- Main Purchase and Submit Receipt methods
    
    internal func restoreSubscriptions(callback: @escaping ([ApphudSubscription]?) -> Void) {
        self.restoreSubscriptionCallback = callback
        self.submitReceiptRestore(allowsReceiptRefresh: true)
    }
    
    internal func submitReceiptAutomaticPurchaseTracking() {
        
        if isSubmittingReceipt {return}
        
        performWhenUserRegistered {
            guard let receiptString = receiptDataString() else { return }
            self.submitReceipt(receiptString: receiptString, notifyDelegate: true, callback: nil)
        }
    }
    
    internal func submitReceiptRestore(allowsReceiptRefresh : Bool) {
        guard let receiptString = receiptDataString() else {
            if allowsReceiptRefresh {
                apphudLog("App Store receipt is missing on device, will refresh first then retry")
                ApphudStoreKitWrapper.shared.refreshReceipt()
            } else {
                apphudLog("App Store receipt is missing on device and couldn't be refreshed.", forceDisplay: true)
                self.restoreSubscriptionCallback?(nil)
                self.restoreSubscriptionCallback = nil
            }
            return 
        }
        
        let exist = performWhenUserRegistered { 
            self.submitReceipt(receiptString: receiptString, notifyDelegate: true) { error in
                self.restoreSubscriptionCallback?(self.currentUser?.subscriptions)
                self.restoreSubscriptionCallback = nil
            }
        }
        if !exist {
            apphudLog("Tried to make restore allows: \(allowsReceiptRefresh) request when user is not yet registered, addind to schedule..")
        }
    }
    
    internal func submitReceipt(productId : String, callback : ((ApphudSubscription?, Error?) -> Void)?) {
        guard let receiptString = receiptDataString() else { 
            ApphudStoreKitWrapper.shared.refreshReceipt()
            callback?(nil, ApphudError.error(message: "Receipt not found on device, refreshing."))
            return 
        }
        
        let exist = performWhenUserRegistered { 
            self.submitReceipt(receiptString: receiptString, notifyDelegate: true) { error in                
                callback?(self.subscription(productId: productId), error)
            }            
        }
        if !exist {
            apphudLog("Tried to make submitReceipt: \(productId) request when user is not yet registered, addind to schedule..")
        }
    }
    
    private func submitReceipt(receiptString : String, notifyDelegate : Bool, callback : ((Error?) -> Void)?) {
        
        if callback != nil {
            self.submitReceiptCallback = callback
        }
        
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
                        self.delegate?.apphudSubscriptionsUpdated?(self.currentUser!.subscriptions)
                    }
                }
            }
            
            self.submitReceiptCallback?(error)
            self.submitReceiptCallback = nil
        }
    }
    
    internal func purchase(product: SKProduct, callback: ((ApphudSubscription?, Error?) -> Void)?){
        ApphudStoreKitWrapper.shared.purchase(product: product) { transaction in
            self.handleTransaction(product: product, transaction: transaction) { (subscription, transaction, error) in
                callback?(subscription, error)
            }
        }
    }    
    
    internal func purchase(product: SKProduct, callback: ((ApphudSubscription?, SKPaymentTransaction?, Error?) -> Void)?){
        ApphudStoreKitWrapper.shared.purchase(product: product) { transaction in
            self.handleTransaction(product: product, transaction: transaction) { (subscription, transaction, error) in
                callback?(subscription, transaction, error)
            }
        }
    }
    
    @available(iOS 12.2, *)
    internal func purchasePromo(product: SKProduct, discountID: String, callback: ((ApphudSubscription?, Error?) -> Void)?){
        self.signPromoOffer(productID: product.productIdentifier, discountID: discountID) { (paymentDiscount, error) in
            if let paymentDiscount = paymentDiscount {  
                self.purchasePromo(product: product, discount: paymentDiscount) { (subscription, transaction, error) in
                    callback?(subscription, error)
                }
            } else {
                callback?(nil, ApphudError.error(message: "Could not sign offer id: \(discountID), product id: \(product.productIdentifier)"))
            }
        }
    }
    
    @available(iOS 12.2, *)
    internal func purchasePromo(product: SKProduct, discountID: String, callback: ((ApphudSubscription?, SKPaymentTransaction?, Error?) -> Void)?){
        self.signPromoOffer(productID: product.productIdentifier, discountID: discountID) { (paymentDiscount, error) in
            if let paymentDiscount = paymentDiscount {                
                self.purchasePromo(product: product, discount: paymentDiscount, callback: callback)
            } else {
                callback?(nil, nil, ApphudError.error(message: "Could not sign offer id: \(discountID), product id: \(product.productIdentifier)"))
            }
        }
    }
    
    @available(iOS 12.2, *)
    internal func purchasePromo(product: SKProduct, discount: SKPaymentDiscount, callback: ((ApphudSubscription?, SKPaymentTransaction?, Error?) -> Void)?){
        ApphudStoreKitWrapper.shared.purchase(product: product, discount: discount) { transaction in
            self.handleTransaction(product: product, transaction: transaction, callback: callback)
        }
    }
    
    private func handleTransaction(product: SKProduct, transaction: SKPaymentTransaction, callback: ((ApphudSubscription?, SKPaymentTransaction?, Error?) -> Void)?){
        if transaction.transactionState == .purchased {
            self.submitReceipt(productId: product.productIdentifier) { (subscription, error) in
                SKPaymentQueue.default().finishTransaction(transaction)
                callback?(subscription, transaction, error)
            }
        } else {
            callback?(subscription(productId: product.productIdentifier), transaction, transaction.error)
        }
    }
    
    private func subscription(productId: String) -> ApphudSubscription? {
        
        // 1. try to find subscription by product id
        var subscription = Apphud.subscriptions()?.first(where: {$0.productId == productId})
        
        // 2. try to find subscription by SKProduct's subscriptionGroupIdentifier
        if subscription == nil, #available(iOS 12.2, *){
            let targetProduct = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == productId})
            for sub in Apphud.subscriptions() ?? [] {
                if let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == sub.productId}),
                targetProduct?.subscriptionGroupIdentifier == product.subscriptionGroupIdentifier {
                    subscription = sub
                    break
                }
            }
        }
        
        // 3. Try to find subscription by groupID provided in Apphud project settings
        if subscription == nil, let groupID = self.productsGroupsMap?[productId] {
            subscription = Apphud.subscriptions()?.first(where: { self.productsGroupsMap?[$0.productId] == groupID})
        }
        
        return subscription
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
    
    //MARK:- Eligibilities API
    
    @available(iOS 12.2, *)
    internal func checkEligibilitiesForPromotionalOffers(products: [SKProduct], callback: @escaping ApphudEligibilityCallback){
        
        let result = performWhenUserRegistered {
            
            apphudLog("User registered, check promo eligibility")
            
            let didSendReceiptForPromoEligibility = "ReceiptForPromoSent"
            
            // not found subscriptions, try to restore and try again
            if self.currentUser?.subscriptions.count ?? 0 == 0 && !UserDefaults.standard.bool(forKey: didSendReceiptForPromoEligibility){
                if let receiptString = receiptDataString() {
                    apphudLog("Restoring subscriptions for promo eligibility check")
                    self.submitReceipt(receiptString: receiptString, notifyDelegate: true, callback: { error in
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
    internal func checkEligibilitiesForIntroductoryOffers(products: [SKProduct], callback: @escaping ApphudEligibilityCallback){

        let result = performWhenUserRegistered {
            
            apphudLog("User registered, check intro eligibility")
            
            // not found subscriptions, try to restore and try again
            
            let didSendReceiptForIntroEligibility = "ReceiptForIntroSent"
            
            if self.currentUser?.subscriptions.count ?? 0 == 0 && !UserDefaults.standard.bool(forKey: didSendReceiptForIntroEligibility){
                if let receiptString = receiptDataString() {
                    apphudLog("Restoring subscriptions for intro eligibility check")
                    self.submitReceipt(receiptString: receiptString, notifyDelegate: true, callback: { error in
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
    
    //MARK:- Push Notifications API
    
    internal func submitPushNotificationsToken(token: Data, callback: ApphudBoolCallback?){
        performWhenUserRegistered {
            let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
            let params : [String : String] = ["device_id" : self.currentDeviceID, "push_token" : tokenString]
            self.httpClient.startRequest(path: "customers/push_token", params: params, method: .put) { (result, response, error) in
                callback?(result)
            }             
        }
    }
    
    //MARK:- V2 API
    
    internal func trackEvent(params: [String : AnyHashable], callback: @escaping ()->Void){
        
        let result = performWhenUserRegistered {
            let final_params : [String : AnyHashable] = ["device_id" : self.currentDeviceID].merging(params, uniquingKeysWith: {(current,_) in current})
            self.httpClient.startRequest(path: "events", apiVersion: .v2, params: final_params, method: .post) { (result, response, error) in
                callback()
            }
        }
        if !result {
            apphudLog("Tried to trackRuleEvent, but user not yet registered, adding to schedule")
        }
    }
    
    /// Not used yet
    internal func getRule(ruleID: String, callback: @escaping (ApphudRule?) -> Void){
        
        let result = performWhenUserRegistered {
            let params = ["device_id": self.currentDeviceID] as [String : String]
            
            self.httpClient.startRequest(path: "rules/\(ruleID)", apiVersion: .v2, params: params, method: .get) { (result, response, error) in
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
            let params = ["device_id": self.currentDeviceID] as [String : String]
            self.httpClient.startRequest(path: "notifications", apiVersion: .v2, params: params, method: .get, callback: { (result, response, error) in
                
                if result, let dataDict = response?["data"] as? [String : Any], let notifArray = dataDict["results"] as? [[String : Any]], let notifDict = notifArray.first, let ruleDict = notifDict["rule"] as? [String : Any] {
                    let rule = ApphudRule(dictionary: ruleDict)
                    ApphudRulesManager.shared.handleRule(rule: rule)
                }
            })
        }
    }
    
    internal func readAllNotifications(for ruleID: String){
        performWhenUserRegistered {
            let params = ["device_id": self.currentDeviceID, "rule_id": ruleID] as [String : String]
            self.httpClient.startRequest(path: "notifications/read", apiVersion: .v2, params: params, method: .post, callback: { (result, response, error) in
            })
        }
    }
    
    //MARK:- Attribution
    internal func addAttribution(data: [AnyHashable : Any], from provider: ApphudAttributionProvider, identifer: String? = nil, callback: ((Bool) -> Void)?){
        performWhenUserRegistered {
            
            var params : [String : Any] = ["device_id" : self.currentDeviceID]
            
            if provider == .appsFlyer {
                guard identifer != nil else { 
                    callback?(false)
                    return 
                }   
                params["appsflyer_id"] = identifer
                params["appsflyer_data"] = data
            }
            
            self.httpClient.startRequest(path: "customers/attribution", params: params, method: .post) { (result, response, error) in
                callback?(result)
            } 
        }
    }
}

/*
    p print(String(data: try! JSONSerialization.data(withJSONObject: response, options: .prettyPrinted), encoding: .utf8 )!)
 */
