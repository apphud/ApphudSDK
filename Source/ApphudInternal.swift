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

let sdk_version = "0.1.1"

final class ApphudInternal {
    
    fileprivate let requiresReceiptSubmissionKey = "requiresReceiptSubmissionKey"
    
    static let shared = ApphudInternal()
    var delegate : ApphudDelegate?
    var currentUser : ApphudUser?
        
    var currentDeviceID : String!
    var currentUserID : String!
    fileprivate var isSubmittingReceipt : Bool = false
    
    fileprivate var httpClient : ApphudHttpClient!
    fileprivate var requires_currency_update = false
        
    typealias UserRegisteredCallback = (() -> Void)
    fileprivate var userRegisteredCallbacks = [UserRegisteredCallback]()
    
    internal func initialize(apiKey: String, userID : String?, deviceIdentifier : String? = nil){
                
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
        
        self.httpClient = ApphudHttpClient(apiKey: apiKey) 
        
        self.currentUser = ApphudUser.fromCache()
        
        if userID != nil {
            self.currentUserID = userID!
        } else if let existingUserID = self.currentUser?.user_id {
            self.currentUserID = existingUserID
        } else {
            self.currentUserID = ApphudKeychain.generateUUID()
        }
                
        registerUser { (result, dictionary, error) in
            if result {
                
                if self.parseUser(dictionary) {
                    self.delegate?.apphudSubscriptionsUpdated?(self.currentUser!.subscriptions!)                    
                }
                
                apphudLog("User successfully registered")
                
                self.performAllUserRegisteredBlocks()
                
                if UserDefaults.standard.bool(forKey: self.requiresReceiptSubmissionKey) {
                    self.restore(allowsReceiptRefresh: false)
                }
                
                self.getProducts(callback: { (result2, dictionary2, error2) in
                    if result2, let dataDict = dictionary2?["data"] as? [String : Any] {
                        if let productsArray = dataDict["results"] as? [[String : Any]] {
                            var productIDs = Set<String>()
                            for product in productsArray {
                                let productID = product["product_id"] as! String
                                productIDs.insert(productID)
                            }
                            if productIDs.count > 0 {
                                ApphudStoreKitWrapper.shared.fetchProducts(identifiers: productIDs) { (skproducts) in
                                    
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
                        }
                    }
                })
            } else {
                apphudLog("Failed to register user, error:\(error?.localizedDescription ?? "")")
                self.userRegisteredCallbacks.removeAll()
            }
        }
    }
    /*
     /// not used yet
    private static func identifierForAdvertising() -> String? {
        // Check whether advertising tracking is enabled
        guard ASIdentifierManager.shared().isAdvertisingTrackingEnabled else {
            return nil
        }
        
        // Get and return IDFA
        return ASIdentifierManager.shared().advertisingIdentifier.uuidString
    }
    */
    
    /*
     Returns a value, indicating whether subscriptions data has changes
     */
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
    @discardableResult internal func performWhenUserRegistered(callback : @escaping UserRegisteredCallback) -> Bool{
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
    
    // MARK: API Requests
    
    private func registerUser(callback: @escaping ApphudBoolDictionaryCallback) {
                
        var params : [String : String] = ["device_id" : self.currentDeviceID]
        if self.currentUserID != nil {
            params["user_id"] = self.currentUserID!
        }
        
        let deviceParams = currentDeviceParameters()
        params.merge(deviceParams) { (current, new) in current}
        
        httpClient.startRequest(path: "customers", params: params, method: .post, callback: callback)        
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
    
    private func getProducts(callback: @escaping ApphudBoolDictionaryCallback) {
        httpClient.startRequest(path: "products", params: nil, method: .get, callback: callback)
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
    
    internal func submitPurchase(productId : String, callback : ((ApphudSubscription?, Error?) -> Void)?) {
        guard let receiptString = receiptDataString() else { 
            ApphudStoreKitWrapper.shared.refreshReceipt()
            callback?(nil, nil)
            return 
        }
        
        let exist = performWhenUserRegistered { 
            self.submitReceipt(receiptString: receiptString, isRestoring: false) { error in
                callback?(Apphud.purchasedSubscriptionFor(productID: productId), error)
            }            
        }
        if !exist {
            apphudLog("Tried to make submitPurchase: \(productId) request when user is not yet registered, addind to schedule..")
        }
    }
    
    internal func restore(allowsReceiptRefresh : Bool) {
        guard let receiptString = receiptDataString() else {
            if allowsReceiptRefresh {
                apphudLog("App Store receipt is missing on device, will refresh first then retry")
                ApphudStoreKitWrapper.shared.refreshReceipt()
            } else {
                // receipt is missing and can't refresh anymore because already tried to refresh
            }
            return 
        }
        
        let exist = performWhenUserRegistered { 
            self.submitReceipt(receiptString: receiptString, isRestoring: true, callback: nil)
        }
        if !exist {
            apphudLog("Tried to make restore allows: \(allowsReceiptRefresh) request when user is not yet registered, addind to schedule..")
        }
    }
    
    fileprivate func submitReceipt(receiptString : String, isRestoring : Bool, callback : ((Error?) -> Void)?) {
        
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
                    if isRestoring {
                        self.delegate?.apphudSubscriptionsUpdated?(self.currentUser!.subscriptions!)
                    }
                }
            }

            callback?(error)
        }
    }
}
