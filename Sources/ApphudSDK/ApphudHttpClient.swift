//
//  ApphudRequestManager.swift
// Apphud
//
//  Created by ren6 on 26/06/2019.
//  Copyright © 2019 Softeam Inc. All rights reserved.
//

import Foundation

typealias ApphudBoolDictionaryCallback = (Bool, [String : Any]?, Error?) -> Void
typealias ApphudStringCallback = (String?, Error?) -> Void
/**
 This is Apphud's internal class.
 */
@available(iOS 11.2, *)
public class ApphudHttpClient {
    
    enum ApphudHttpMethod : String {
        case post = "POST"
        case get = "GET"
        case put = "PUT"
    }
    
    enum ApphudApiVersion : String {
        case v1 = "v1"
        case v2 = "v2"
    }
    
    #if DEBUG
    public static let shared = ApphudHttpClient()
    public var domain_url_string = "https://api.apphud.com"
    #else 
    internal static let shared = ApphudHttpClient()
    internal var domain_url_string = "https://api.apphud.com"
    #endif
    
    internal var apiKey : String = ""
    
    private let session : URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession.init(configuration: config)
    }()
    
    internal func startRequest(path: String, apiVersion: ApphudApiVersion = .v1, params: [String : Any]?, method: ApphudHttpMethod, callback: ApphudBoolDictionaryCallback?) {
        if let request = makeRequest(path: path, apiVersion: apiVersion, params: params, method: method) {
            start(request: request, callback: callback)
        }
    }
    
    internal func loadScreenHtmlData(screenID: String, callback: @escaping (String?, Error?) -> Void) {
        
        if let request = makeScreenRequest(screenID: screenID) {
            
            apphudLog("started loading screen html data:\(request)", forceDisplay: true)
            
            let task = session.dataTask(with: request) { (data, response, error) in
                var string : String?
                if data != nil, let http_response = response as? HTTPURLResponse, http_response.statusCode < 299 {
                    string = String(data: data!, encoding: .utf8)
                }
                DispatchQueue.main.async {
                    callback(string, error)
                }
            }
            task.resume()
            
        } else {
            callback(nil, nil)
        }        
    }
    
    internal func makeScreenRequest(screenID: String) -> URLRequest? {
        
        let deviceID : String = ApphudInternal.shared.currentDeviceID
        let urlString = "\(domain_url_string)/preview_screen/\(screenID)?api_key=\(apiKey)&locale=\(Locale.current.identifier)&device_id=\(deviceID)&v=2"
        
        let url = URL(string: urlString)
        if url != nil {
            let request = URLRequest(url: url!, cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy, timeoutInterval: 20)
            return request
        }
        return nil
    }
    
    private func makeRequest(path : String, apiVersion: ApphudApiVersion, params : [String : Any]?, method : ApphudHttpMethod) -> URLRequest? {
        var request: URLRequest? = nil
        do {
            var url: URL? = nil
            
            let urlString = "\(domain_url_string)/\(apiVersion.rawValue)/\(path)"
            
            if method == .get {
                var components = URLComponents(string: urlString)
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
                url = URL(string: urlString)
            }
            guard let finalURL = url else {
                return nil
            }
            
            request = URLRequest(url: finalURL, cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy, timeoutInterval: 20)
            request?.httpMethod = method.rawValue
            request?.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request?.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
            
            if method != .get {
                var finalParams : [String : Any] = ["api_key" : apiKey]
                if params != nil {
                    finalParams.merge(params!, uniquingKeysWith: {$1})
                }
                let data = try JSONSerialization.data(withJSONObject: finalParams, options: [])
                request?.httpBody = data
            }
        } catch {
            
        }
        
        apphudLog("Start \(method) request \(request?.url?.absoluteString ?? "") params: \(params ?? [:])")
        
        return request
    }
    
    internal func start(request: URLRequest, callback: @escaping ApphudStringCallback){
        let task = session.dataTask(with: request) { (data, response, error) in
            var string : String?
            if data != nil {
                string = String(data: data!, encoding: .utf8)
            }
            DispatchQueue.main.async {
                callback(string, error)
            }
        }
        task.resume()
    }
    
    private func start(request: URLRequest, callback: ApphudBoolDictionaryCallback?){
        let task = session.dataTask(with: request) { (data, response, error) in
            
            var dictionary: [String : Any]?
            
            do {
                if data != nil {
                    dictionary = try JSONSerialization.jsonObject(with: data!, options: []) as? [String : Any]
                }
            } catch {
                
            }
            
            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {
                    
                    let method = request.httpMethod ?? ""
                    
                    let code = httpResponse.statusCode
                    if code >= 200 && code < 300 {
                        
                        if data != nil {
                            let stringResponse = String(data: data!, encoding: .utf8)
                            apphudLog("Request \(method) \(request.url?.absoluteString ?? "") success with response: \n\(stringResponse ?? "")")
                        }
                        callback?(true, dictionary, nil)
                        return
                    }
                    apphudLog("Request \(method) \(request.url?.absoluteString ?? "") failed with code \(code), error: \(error?.localizedDescription ?? "") response: \(dictionary ?? [:])")
                }
                
                callback?(false, nil, error)
            }
            
        }
        task.resume()
    }
}
