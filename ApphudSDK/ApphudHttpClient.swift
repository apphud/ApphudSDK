//
//  ApphudRequestManager.swift
//  Apphud, Inc
//
//  Created by ren6 on 26/06/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import Foundation

internal struct ApphudAPIDataResponse<T: Decodable>: Decodable {
    var data: T
}

internal struct ApphudAPIArrayResponse<T: Decodable>: Decodable {
    var results: [T]
}

typealias ApphudHTTPResponseCallback = (Bool, [String: Any]?, Data?, Error?, Int) -> Void
typealias ApphudStringCallback = (String?, Error?) -> Void
/**
 This is Apphud's internal class.
 */
@available(iOS 11.2, *)
public class ApphudHttpClient {

    enum ApphudHttpMethod: String {
        case post = "POST"
        case get = "GET"
        case put = "PUT"
    }

    enum ApphudApiVersion: String {
        case APIV1 = "v1"
        case APIV2 = "v2"
    }

    static let productionEndpoint = "https://api.apphud.com"
    
    #if DEBUG
    public static let shared = ApphudHttpClient()
    public var domainUrlString = productionEndpoint
    #else
    public static let shared = ApphudHttpClient()
    public var domainUrlString = productionEndpoint
    #endif

    internal var apiKey: String = ""

    internal var canRetry: Bool {
        !invalidAPiKey && !unauthorized
    }
    
    internal var invalidAPiKey: Bool = false
    internal var unauthorized: Bool = false
    
    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession.init(configuration: config)
    }()
    
    private let CACHE_TIMEOUT: TimeInterval = 3600.0
    private let GET_TIMEOUT: TimeInterval = 10.0
    private let POST_PUT_TIMEOUT: TimeInterval = 40.0

    internal func requestInstance(url: URL) -> URLRequest? {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "APPHUD-API-KEY")
        return request
    }

    internal func startRequest(path: String, apiVersion: ApphudApiVersion = .APIV1, params: [String: Any]?, method: ApphudHttpMethod, useDecoder: Bool = false, callback: ApphudHTTPResponseCallback?) {
        if let request = makeRequest(path: path, apiVersion: apiVersion, params: params, method: method) {
            start(request: request, useDecoder: useDecoder, callback: callback)
        }
    }

    internal func loadScreenHtmlData(screenID: String, callback: @escaping (String?, Error?) -> Void) {

        if let data = cachedScreenData(id: screenID), let string = String(data: data, encoding: .utf8) {
            callback(string, nil)
            apphudLog("using cached html data for screen id = \(screenID)", logLevel: .all)
            return
        }
        
        if let request = makeScreenRequest(screenID: screenID) {

            apphudLog("started loading screen html data:\(request)", logLevel: .all)

            let task = session.dataTask(with: request) { (data, response, error) in
                var string: String?
                if let data = data, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 299,
                   let stringData = String(data: data, encoding: .utf8) {
                    self.cacheScreenData(id: screenID, html: data)
                    string = stringData
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

    private func cachedScreenData(id: String) -> Data? {
        guard var url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return nil }
        url = url.appendingPathComponent(id).appendingPathExtension("html")
        
        if FileManager.default.fileExists(atPath: url.path),
           let attrs = try? FileManager.default.attributesOfItem(atPath: url.path),
           let creationDate = attrs[.creationDate] as? Date,
           Date().timeIntervalSince(creationDate) < CACHE_TIMEOUT,
           let data = try? Data(contentsOf: url) {
            return data
        }
        
        return nil
    }
    
    private func cacheScreenData(id: String, html: Data) {
        guard var url = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first else { return }
        url = url.appendingPathComponent(id).appendingPathExtension("html")
        
        if FileManager.default.fileExists(atPath: url.path) {
            try? FileManager.default.removeItem(at: url)
        }
        
        try? html.write(to: url)
    }
    
    internal func makeScreenRequest(screenID: String) -> URLRequest? {

        let deviceID: String = ApphudInternal.shared.currentDeviceID
        let urlString = "\(domainUrlString)/preview_screen/\(screenID)?api_key=\(apiKey)&locale=\(Locale.current.identifier)&device_id=\(deviceID)&v=2"

        if let url = URL(string: urlString) {
            return requestInstance(url: url)
        }

        return nil
    }

    private func makeRequest(path: String, apiVersion: ApphudApiVersion, params: [String: Any]?, method: ApphudHttpMethod) -> URLRequest? {
        var request: URLRequest?
        do {
            var url: URL?

            let urlString = "\(domainUrlString)/\(apiVersion.rawValue)/\(path)"

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
            } else {
                url = URL(string: urlString)
            }
            guard let finalURL = url else {
                return nil
            }

            request = requestInstance(url: finalURL)
            request?.httpMethod = method.rawValue
            request?.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
            request?.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
            request?.setValue("ios", forHTTPHeaderField: "X-Platform")
            request?.timeoutInterval = method == .get ? GET_TIMEOUT : POST_PUT_TIMEOUT
            if method != .get {
                var finalParams: [String: Any] = ["api_key": apiKey]
                if params != nil {
                    finalParams.merge(params!, uniquingKeysWith: {$1})
                }
                let data = try JSONSerialization.data(withJSONObject: finalParams, options: [])
                request?.httpBody = data
            }
        } catch {

        }

        do {
            let string = String(data: try JSONSerialization.data(withJSONObject: params ?? [:], options: .prettyPrinted), encoding: .utf8)

            if ApphudUtils.shared.logLevel == .all {
                apphudLog("Start \(method) request \(request?.url?.absoluteString ?? "") params: \(string ?? "")", logLevel: .all)
            } else {
                apphudLog("Start \(method) request \(request?.url?.absoluteString ?? "")")
            }

        } catch {
        }

        return request
    }

    internal func start(request: URLRequest, callback: @escaping ApphudStringCallback) {
        let task = session.dataTask(with: request) { (data, _, error) in
            var string: String?
            if data != nil {
                string = String(data: data!, encoding: .utf8)
            }
            DispatchQueue.main.async {
                callback(string, error)
            }
        }
        task.resume()
    }

    private func start(request: URLRequest, useDecoder: Bool = false, callback: ApphudHTTPResponseCallback?) {
        let task = session.dataTask(with: request) { (data, response, error) in

            var dictionary: [String: Any]?

            do {
                if data != nil && (!useDecoder || apphudIsSandbox()){
                    dictionary = try JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                }
            } catch {

            }

            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {

                    let method = request.httpMethod ?? ""

                    let code = httpResponse.statusCode
                    if code >= 200 && code < 300 {

                        if let dictionary = dictionary {
                            if ApphudUtils.shared.logLevel == .all,
                               let json = try? JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted),
                               let string = String(data: json, encoding: .utf8) {
                                apphudLog("Request \(method) \(request.url?.absoluteString ?? "") success with response: \n\(string)", logLevel: .all)
                            } else {
                                apphudLog("Request \(method) \(request.url?.absoluteString ?? "") success")
                            }
                        }

                        callback?(true, dictionary, data, nil, code)
                        return
                    } else if code == 401 {
                        self.invalidAPiKey = true
                        apphudLog("Unable to perform API requests, because your API Key is invalid.", forceDisplay: true)
                    } else if code == 403 {
                        self.unauthorized = true
                        apphudLog("Unable to perform API requests, because your account has been suspended.", forceDisplay: true)
                    }

                    if ApphudUtils.shared.logLevel == .all {
                        apphudLog("Request \(method) \(request.url?.absoluteString ?? "") failed with code \(code), error: \(error?.localizedDescription ?? "") response: \(dictionary ?? [:])", logLevel: .all)
                    } else {
                        apphudLog("Request \(method) \(request.url?.absoluteString ?? "") failed with code \(code), error: \(error?.localizedDescription ?? "")")
                    }

                    var finalError = error
                    
                    if code == 422 && dictionary != nil {
                        finalError = self.parseError(dictionary!)
                    }
                    
                    callback?(false, nil, data, finalError, code)
                } else {
                    let code = (error as NSError?)?.code ?? NSURLErrorUnknown
                    callback?(false, nil, data, error, code)
                }
            }
        }
        task.resume()
    }
    
    private func parseError(_ dictionary: [String: Any]) -> Error? {
        if let errors = dictionary["errors"] as? [[String: Any]], let errorDict = errors.first, let errorMessage = errorDict["title"] as? String {
            return ApphudError(message: errorMessage)
        } else {
            return nil
        }
    }
}
