//
//  Apphud.swift
//  Apphud
//
//  Created by ren6 on 28/04/2019.
//  Copyright © 2019 Softeam. All rights reserved.
//

import UIKit
import StoreKit
import AdSupport

// MARK:- PUBLIC

final public class Apphud: NSObject {
    
    public var configuration : ApphudConfiguration!
    
    /**
     Initializes Apphud SDK.
     
     This is mandatory initialize method. Better to call it within `application:didFinishLaunchingWithOptions:`.
     
     - parameter apiKey: Required. Your api key.
     - parameter userID: Optional. You can provide your own unique user identifier. If nil then NSUUID will be generated instead.
     */
    public static func start(apiKey: String, configuration : ApphudConfiguration? = nil) {
        
        if shared == nil {
            shared = Apphud()
        } else {
            return
        }
        
        if configuration == nil {
            let config = ApphudConfiguration(anUserID: Apphud.getUserID())
            shared.configuration = config
        } else {
            shared.configuration = configuration!
        }

        shared.httpClient = ApphudHttpClient(apiKey: apiKey)       
        shared.initialize()
    }
    
    /**
     Reports successfully purchased product to Apphud server. 
     
     Call it after purchase has been made. Apphud servers will validate receipt automatically and send purchase events to your Analytics when trial is converted to paid subscription. If this is a non trial subscription then events to Analytics will be sent immediately.     
     
     - parameter product: Required. This is an SKProduct class object that has been purchased.
     - parameter callback: Optional. Returns true if revenue has been successfully submitted. Returns false and `error` otherwise. Note that `error` may be nil.
     */
    public static func submitPurchase(product : SKProduct, callback : ((ApphudSubscription?, Error?) -> Void)?) {
        guard shared != nil else {
            #warning("Uninitialized error")
            callback?(nil, nil)
            return
        }
        shared.submitPurchase(product: product, callback: callback)
    }
    
    /**
     Returns true if subscription state is trial or active. You should unlock premium functionality for this subscription. Returns false when subscription is expired. If you want to get more details (state, expiration date, purchase date) you should use activeSubscription method.
     - parameter productID: Required. Product identifier of subscription.
     */
    public static func isSubscriptionActiveFor(productID: String) -> Bool {
        guard let subscription = subscriptionFor(productID: productID) else { return false }
        return subscription.status == .active || subscription.status == .trial
    }
    
    /**
     Returns a subscription with given product identifier. Returns nil if subscription has never been purchased with given product identifier.
     - parameter productID: Required. Product identifier of subscription.
     */
    public static func subscriptionFor(productID: String) -> ApphudSubscription? {
        return subscriptions()?.first(where: {$0.productId == productID})
    }
    
    /**
     Returns an array of all auto-renewable subscriptions that this user has ever purchased.
     */
    public static func subscriptions() -> [ApphudSubscription]? {
        return shared.currentUser?.subscriptions
    }
    
    // MARK:- PRIVATE
    
    fileprivate static var shared: Apphud!
    fileprivate var httpClient : ApphudHttpClient!
    fileprivate var requires_currency_update = false
    fileprivate var currentUser : ApphudUser?
    
    private func initialize(){
        registerUser { (result, dictionary, error) in
            if result {
                self.parseUser(dictionary)
                print("Apphud: User submitted")
                self.getProducts(callback: { (result2, dictionary2, error2) in
                    if result2, let dataDict = dictionary2?["data"] as? [String : Any] {
                        if let productsArray = dataDict["results"] as? [[String : Any]] {
                            var productIDs = Set<String>()
                            for product in productsArray {
                                let productID = product["product_id"] as! String
                                print("Apphud: Product received: ", productID)
                                productIDs.insert(productID)
                            }
                            if productIDs.count > 0 {
                                let productsRequest = SKProductsRequest(productIdentifiers: productIDs)
                                productsRequest.delegate = self
                                productsRequest.start()
                            }
                        }
                    }
                })
            } else {
                print("Apphud: User submit error : \(error?.localizedDescription ?? "")")
            }
        }
    }
    
    private func submitPurchase(product : SKProduct, callback : ((ApphudSubscription?, Error?) -> Void)?) {
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
            callback?(nil, nil)
            return
        }
        var receiptData: Data? = nil
        do {
            receiptData = try Data(contentsOf: appStoreReceiptURL)
        }
        catch {}
        if receiptData == nil {
            callback?(nil, nil)
            return
        }
        
        var environment = "production"
        #if DEBUG
        environment = "sandbox"
        #endif
        var params : [String : Any] = ["user_id" : configuration.user_id,
                                       "receipt_data" : receiptData!.base64EncodedString(),
                                       "environment" : environment]
        
        params.merge(product.submittableParameters(), uniquingKeysWith: {$1})
        
        httpClient.startRequest(path: "subscriptions", params: params, method: .post) { (result, response, error) in
            
            #warning("finish here, parse subscriptions or fetch current user or change response to current user")
            self.registerUser { (result, response, error) in
                if result {
                    self.parseUser(response)
                    callback?(Apphud.subscriptionFor(productID: product.productIdentifier), error)
                }
            }
        }
    }
    
    private class func getUserID() -> String {
        if let anUserID = ApphudKeychain.loadUserID() {
            return anUserID
        } else {
            let anUserID = ApphudKeychain.generateUserID()
            return anUserID
        }
    }
    
    private static func identifierForAdvertising() -> String? {
        // Check whether advertising tracking is enabled
        guard ASIdentifierManager.shared().isAdvertisingTrackingEnabled else {
            return nil
        }
        
        // Get and return IDFA
        return ASIdentifierManager.shared().advertisingIdentifier.uuidString
    }
    
    private func parseUser(_ dict : [String : Any]?){
        guard let dataDict = dict?["data"] as? [String : Any] else {
            return
        }
        guard let userDict = dataDict["results"] as? [String : Any] else {
            return
        }
        let currency = userDict["currency"] 
        if currency is NSNull {
            requires_currency_update = true            
        } 
        
        self.currentUser = ApphudUser(dictionary: userDict)
        ApphudUser.toCache(userDict)
    }
    
    // MARK: API Requests
    
    private func registerUser(callback: @escaping ApphudBoolDictionaryCallback) {
        
        self.currentUser = ApphudUser.fromCache()
        let locale = Locale.current.identifier        
        let params : [String : Any] = ["user_id" : configuration.user_id, 
                                       "locale" : locale]
               
        httpClient.startRequest(path: "customers", params: params, method: .post, callback: callback)        
    }
    
    private func updateUserCurrencyIfNeeded(priceLocale : Locale){
        guard requires_currency_update else { return }
        guard let countryCode = priceLocale.regionCode else { return }
        guard let currencyCode = priceLocale.currencyCode else { return }
        
        let params : [String : Any] = ["country_code" : countryCode,
                                       "currency_code" : currencyCode,
                                       "user_id" : configuration.user_id]
    
        updateUser(fields: params) { (result, response, error) in
                self.requires_currency_update = false
                self.parseUser(response)
                print("response: \(response) error: \(error)")
        }
    }
    
    private func updateUser(fields: [String : Any], callback: @escaping ApphudBoolDictionaryCallback){
        httpClient.startRequest(path: "customers", params: fields, method: .post, callback: callback)
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
        
        print("submitting product: \n\(params)")
        
        httpClient.startRequest(path: "products", params: params, method: .put, callback: callback)        
    }    
}

extension Apphud : SKProductsRequestDelegate {
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if response.products.count > 0 {
            print("Apphud: Products info received from Apple \(response.products)")
            
            updateUserCurrencyIfNeeded(priceLocale: response.products.first!.priceLocale)
            
            self.submitProducts(products: response.products, callback: { (result3, dictionary3, error3) in
                if result3 {
                    print("Apphud: Products submitted")
                } else {
                    print("Apphud: Products submit error: \(error3?.localizedDescription ?? "")")
                }
            })
        }
    }
}
/*
 p print(String(data: try! JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted), encoding: .utf8 )!)
 */
