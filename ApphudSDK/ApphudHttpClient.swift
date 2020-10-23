//
//  ApphudRequestManager.swift
//  Apphud, Inc
//
//  Created by ren6 on 26/06/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import Foundation

typealias ApphudHTTPResponseCallback = (Bool, [String: Any]?, Error?, Int) -> Void
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

    #if DEBUG
    public static let shared = ApphudHttpClient()
    public var domainUrlString = "https://api.apphud.com"
    #else
    internal static let shared = ApphudHttpClient()
    internal var domainUrlString = "https://api.apphud.com"
    #endif

    internal var apiKey: String = ""

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession.init(configuration: config)
    }()

    internal func requestInstance(url: URL) -> URLRequest? {
        var request = URLRequest(url: url, cachePolicy: URLRequest.CachePolicy.useProtocolCachePolicy, timeoutInterval: 20)
        request.setValue(apiKey, forHTTPHeaderField: "APPHUD-API-KEY")
        return request
    }

    internal func startRequest(path: String, apiVersion: ApphudApiVersion = .APIV1, params: [String: Any]?, method: ApphudHttpMethod, callback: ApphudHTTPResponseCallback?) {
        if let request = makeRequest(path: path, apiVersion: apiVersion, params: params, method: method) {
            start(request: request, callback: callback)
        }
    }

    internal func loadScreenHtmlData(screenID: String, callback: @escaping (String?, Error?) -> Void) {

        if let request = makeScreenRequest(screenID: screenID) {

            apphudLog("started loading screen html data:\(request)", logLevel: .all)

            let task = session.dataTask(with: request) { (data, response, error) in
                var string: String?
                if data != nil, let httpResponse = response as? HTTPURLResponse, httpResponse.statusCode < 299 {
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

    private func start(request: URLRequest, callback: ApphudHTTPResponseCallback?) {
        let task = session.dataTask(with: request) { (data, response, error) in

            var dictionary: [String: Any]?

            do {
                if data != nil {
                    dictionary = try JSONSerialization.jsonObject(with: data!, options: []) as? [String: Any]
                }
            } catch {

            }

            DispatchQueue.main.async {
                if let httpResponse = response as? HTTPURLResponse {

                    let method = request.httpMethod ?? ""

                    let code = httpResponse.statusCode
                    if code >= 200 && code < 300 {

                        if let dictionary = dictionary,
                            let json = try? JSONSerialization.data(withJSONObject: dictionary, options: .prettyPrinted),
                            let string = String(data: json, encoding: .utf8) {

                            if ApphudUtils.shared.logLevel == .all {
                                apphudLog("Request \(method) \(request.url?.absoluteString ?? "") success with response: \n\(string)", logLevel: .all)
                            } else {
                                apphudLog("Request \(method) \(request.url?.absoluteString ?? "") success")
                            }

                        }

                        callback?(true, dictionary, nil, code)
                        return
                    }

                    if ApphudUtils.shared.logLevel == .all {
                        apphudLog("Request \(method) \(request.url?.absoluteString ?? "") failed with code \(code), error: \(error?.localizedDescription ?? "") response: \(dictionary ?? [:])", logLevel: .all)
                    } else {
                        apphudLog("Request \(method) \(request.url?.absoluteString ?? "") failed with code \(code), error: \(error?.localizedDescription ?? "")")
                    }

                    callback?(false, nil, error, code)
                } else {
                    callback?(false, nil, error, 0)
                }
            }
        }
        task.resume()
    }
}
