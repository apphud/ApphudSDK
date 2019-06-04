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

private typealias ApphudBoolDictionaryCallback = (Bool, [String : Any]?, Error?) -> Void

public class Apphud: NSObject {
    
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
        }
        if configuration == nil {
            let config = ApphudConfiguration(anUserID: Apphud.getUserID())
            shared.configuration = config
        } else {
            shared.configuration = configuration!
        }
        shared.apiKey = apiKey        
        shared.initialize()
    }
    
    /**
     Reports successfully purchased product to Apphud server. 
     
     Call it after purchase has been made. Apphud servers will validate receipt automatically and send purchase events to your Analytics when trial is converted to paid subscription. If this is a non trial subscription then events to Analytics will be sent immediately.     
     
     - parameter product: Required. This is an SKProduct class object that has been purchased.
     - parameter callback: Optional. Returns true if revenue has been successfully submitted. Returns false and `error` otherwise. Note that `error` may be nil.
     */
    public static func reportRevenue(product : SKProduct, callback : ((Bool, Error?) -> Void)?) {
        guard let manager = shared else {
            callback?(false, nil)
            return
        }
        guard let currencyCode = product.priceLocale.currencyCode else {
            callback?(false, nil)
            return
        }
        guard let appStoreReceiptURL = Bundle.main.appStoreReceiptURL else {
            callback?(false, nil)
            return
        }
        var receiptData: Data? = nil
        do {
            receiptData = try Data(contentsOf: appStoreReceiptURL)
        }
        catch {}
        if receiptData == nil {
            callback?(false, nil)
            return
        }
        
        var environment = "production"
        #if DEBUG
        environment = "sandbox"
        #endif
        let params : [String : Any] = ["user_id" : manager.configuration.user_id,
                                       "currency" : currencyCode,
                                       "price" : product.price.doubleValue,
                                       "receipt_data" : receiptData!.base64EncodedString(),
                                       "environment" : environment]
        
        if let request = manager.getRequest(path: "subscriptions", params: params, method: "POST") {
            manager.start(request: request) { (result, info, error) in
                callback?(result, error)
            }
        }
    }
    
    // MARK:- PRIVATE
    
    private static var shared: Apphud!
    private var apiKey : String = ""
    private let domain_url_string = "http://analytics.atlantapps.com"
    
    private lazy var session : URLSession = {
        let config = URLSessionConfiguration.default
        return URLSession.init(configuration: config)
    }()
    
    private func initialize(){
        registerUser { (result, dictionary, error) in
            if result {
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
    
    // MARK: API Requests
    
    private func registerUser(callback: @escaping ApphudBoolDictionaryCallback) {
        guard let currencyCode = Locale.current.currencyCode else {
            callback(false, nil, nil)
            return
        }
        let params: [String : Any] = ["user_id" : configuration.user_id, "locale" : Locale.current.identifier, "currency" : currencyCode]
        if let request = getRequest(path: "users", params: params, method: "POST") {
            start(request: request, callback: callback)
        }
    }
    
    private func getProducts(callback: @escaping ApphudBoolDictionaryCallback) {
        if let request = getRequest(path: "products", params: nil, method: "GET") {
            start(request: request, callback: callback)
        }
    }
    
    private func submitProducts(products: [SKProduct], callback : @escaping ApphudBoolDictionaryCallback) {
        var array = [[String : Any]]()
        for product in products {
            if let currencyCode = product.priceLocale.currencyCode {
                let product_json : [String : Any] = ["product_id" : product.productIdentifier,
                                                     "currency" : currencyCode,
                                                     "price" : product.price.doubleValue]
                array.append(product_json)
            }
        }
        let params = ["products" : array] as [String : Any]
        if let request = getRequest(path: "products", params: params, method: "PUT") {
            start(request: request, callback: callback)
        }
    }
    
    // MARK: Request Helpers
    
    private func getRequest(path : String, params : [String : Any]?, method : String) -> URLRequest? {
        var request: URLRequest? = nil
        do {
            var url: URL? = nil
            if method == "GET" {
                var components = URLComponents(string: "\(domain_url_string)/v1/app/\(path)")
                var items: [URLQueryItem] = [URLQueryItem(name: "api_key", value: apiKey)]
                if let requestParams = params {
                    for key in requestParams.keys {
                        items.append(URLQueryItem(name: key, value: requestParams[key] as? String))
                    }
                }
                components?.queryItems = items
                url = components?.url
            }
            else {
                url = URL(string: "\(domain_url_string)/v1/app/\(path)")
            }
            guard let finalURL = url else {
                return nil
            }
            
            request = URLRequest(url: finalURL, cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy, timeoutInterval: 20)
            request?.httpMethod = method
            request?.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request?.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
            
            if method != "GET" {
                var finalParams : [String : Any] = ["api_key" : apiKey]
                if params != nil {
                    finalParams.merge(params!, uniquingKeysWith: {$1})
                }
                let data = try JSONSerialization.data(withJSONObject: finalParams, options: .prettyPrinted)
                request?.httpBody = data
            }
        } catch {
            
        }
        return request
    }
    
    private func start(request: URLRequest, callback: ApphudBoolDictionaryCallback?){
        let task = session.dataTask(with: request) { (data, response, error) in
            if let httpResponse = response as? HTTPURLResponse {
                let code = httpResponse.statusCode
                if code < 300 {
                    var dictionary: [String : Any]?
                    if data != nil {
                        do {
                            dictionary = try JSONSerialization.jsonObject(with: data!, options: []) as? [String:Any]
                        } catch {}
                    }
                    callback?(true, dictionary, nil)
                    return
                }
            }
            callback?(false, nil, error)
        }
        task.resume()
    }
}

extension Apphud : SKProductsRequestDelegate {
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        if response.products.count > 0 {
            print("Apphud: Products info received from Apple \(response.products)")
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
 
 POST /v1/users?user_id={user_id}&locale={locale}&currency={currency}&api_key={api_key} — Create User
 GET /v1/products?api_key={api_key} – Получить список product_id, чтобы запросить для них актуальную цену с устройства.
 PUT /v1/products?api_key={api_key}&product_id={product_id}&currency={currency}&price={price} – Обновить цену продукта для конкретной валюты, после её создания конвертируем эту валюту в бакс и записываем цену в баксах в отдельную колонку.
 POST /v1/subscriptions?user_id={user_id}&receipt_data={receipt_data}&receipt={receipt}&api_key={api_key}&price={price}&currency={currency} – Create Subscription. Тут во время создания подписки мы имеем receipt, из которого получаем оплаченый product_id, с помощью него мы узнаем актуальную цену в баксах на этот продукт в нашей бд и эта цена записывается жестко в саму подписку, далее каждый ребил будет считаться по этой цене и отправляться в аналитику. Если продукт не найден в нашей бд по каким-то причинам, то создаем этот продукт и цену для него.
 
 Александр Селиванов, [28 Apr 2019 at 09:23:23]:
 PUT /v1/products?api_key={api_key}&products={products} – Обновить цену продукта для конкретной валюты, после её создания конвертируем эту валюту в бакс и записываем цену в баксах в отдельную колонку.
 
 {products} = {
 product_id: product_id,
 currency: currency,
 price: price
 }
 
 вот этот ендпоинт лучше массово все цены по нужным продуктам слать.
 */
