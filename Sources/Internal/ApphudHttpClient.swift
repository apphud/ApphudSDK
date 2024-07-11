//
//  ApphudRequestManager.swift
//  Apphud, Inc
//
//  Created by ren6 on 26/06/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import Foundation

internal struct ApphudUserResponse<T: Decodable>: Decodable {
    var data: ApphudUserResultsResponse<T>
}

internal struct ApphudUserResultsResponse<T: Decodable>: Decodable {
    var results: T
}

internal struct ApphudAPIDataResponse<T: Decodable>: Decodable {
    var data: T
}

internal struct ApphudAPIArrayResponse<T: Decodable>: Decodable {
    var results: [T]
}

typealias ApphudParsedResponse = (Bool, [String: Any]?, Data?, Error?, Int)
typealias ApphudHTTPResponse = (Bool, [String: Any]?, Data?, Error?, Int, Double, Int)
typealias ApphudHTTPResponseCallback = (Bool, [String: Any]?, Data?, Error?, Int, Double, Int) -> Void
typealias ApphudStringCallback = (String?, Error?) -> Void
/**
 This is Apphud's internal class.
 */
public class ApphudHttpClient {

    enum ApphudHttpMethod: String {
        case post = "POST"
        case get = "GET"
        case put = "PUT"
    }

    enum ApphudApiVersion: String {
        case APIV1 = "v1"
        case APIV2 = "v2"
        case APIV3 = "v3"
    }

    enum ApphudEndpoint: Equatable {

        case customers, push, logs, events, screens, attribution, products, paywalls, subscriptions, signOffer, promotions, properties, receipt, notifications, readNotifications, rule(String)

        var value: String {
            switch self {
            case .customers:
                return "customers"
            case .push:
                return "customers/push_token"
            case .logs:
                return "logs"
            case .events:
                return "events"
            case .screens:
                return "rules/screens"
            case .attribution:
                return "customers/attribution"
            case .products:
                return "products"
            case .paywalls:
                return "paywall_configs"
            case .subscriptions:
                return "subscriptions"
            case .signOffer:
                return "sign_offer"
            case .promotions:
                return "promotions"
            case .properties:
                return "customers/properties"
            case .receipt:
                return "subscriptions/raw"
            case .notifications:
                return "notifications"
            case .readNotifications:
                return "notifications/read"
            case .rule(let ruleID):
                return "rules/\(ruleID)"
            }
        }
    }

    static let productionEndpoint = "https://gateway.apphud.com"
    public var sdkType: String = "swift"
    public var sdkVersion: String = apphud_sdk_version

    public static let shared = ApphudHttpClient()
    public var domainUrlString = productionEndpoint

    internal var apiKey: String = ""

    internal var canRetry: Bool {
        !invalidAPiKey && !unauthorized
    }

    internal var invalidAPiKey: Bool = false
    internal var unauthorized: Bool = false
    internal var suspended: Bool = false

    private let session: URLSession = {
        let config = URLSessionConfiguration.default
        config.requestCachePolicy = .reloadIgnoringLocalCacheData
        config.urlCache = nil
        return URLSession.init(configuration: config)
    }()

    private let GET_TIMEOUT: TimeInterval = 7.0
    public var POST_CUSTOMERS_TIMEOUT: TimeInterval = 7.0
    private let POST_TIMEOUT: TimeInterval = 20.0

    internal func requestInstance(url: URL) -> URLRequest? {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "APPHUD-API-KEY")
        return request
    }

    internal func canSwizzlePayment() -> Bool {
        if ApphudUtils.shared.storeKitObserverMode == true && ApphudUtils.shared.isFlutter {
            return false
        } else {
            return true
        }
    }

    internal func startRequest(path: ApphudEndpoint, apiVersion: ApphudApiVersion = .APIV1, params: [String: Any]?, method: ApphudHttpMethod, useDecoder: Bool = false, retry: Bool = false, requestID: String? = nil, callback: ApphudHTTPResponseCallback?) {

        let timeout = path == .customers ? POST_CUSTOMERS_TIMEOUT : nil

        if let request = makeRequest(path: path.value, apiVersion: apiVersion, params: params, method: method, defaultTimeout: timeout, requestID: requestID), !suspended {
            Task(priority: .userInitiated) {

                let retries: Int
                let retryDelay: TimeInterval

                if retry {
                    retries = ApphudInternal.shared.customRegistrationAttemptsCount ?? APPHUD_DEFAULT_RETRIES
                    retryDelay = 1.0
                } else {
                    retries = 0
                    retryDelay = 0
                }

                let response = await start(request: request, useDecoder: useDecoder, retries: retries, delay: retryDelay)

                Task { @MainActor in
                    callback?(response.0, response.1, response.2, response.3, response.4, response.5, response.6)
                }
            }
        } else {
            apphudLog("Unable to perform API requests, because your account has been suspended.", forceDisplay: true)
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
           Date().timeIntervalSince(creationDate) < ApphudInternal.shared.cacheTimeout,
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

    private func makeRequest(path: String, apiVersion: ApphudApiVersion, params: [String: Any]?, method: ApphudHttpMethod, defaultTimeout: TimeInterval? = nil, requestID: String? = nil) -> URLRequest? {

        var request: URLRequest?

        var url: URL?

        let urlString = "\(domainUrlString)/\(apiVersion.rawValue)/\(path)"

        if method == .get {
            var components = URLComponents(string: urlString)
            var items: [URLQueryItem] = [URLQueryItem(name: "api_key", value: apiKey)]
            if let requestParams = params {
                for key in requestParams.keys {
                    items.append(URLQueryItem(name: key, value: (requestParams[key] as? LosslessStringConvertible)?.description))
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

        var platform = "ios"
        #if os(macOS)
        platform = "macos"
        #endif

        request = requestInstance(url: finalURL)
        request?.httpMethod = method.rawValue
        request?.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Content-Type")
        request?.setValue("application/json; charset=utf-8", forHTTPHeaderField: "Accept")
        request?.setValue(platform, forHTTPHeaderField: "X-Platform")
        request?.setValue(self.sdkType, forHTTPHeaderField: "X-SDK")
        request?.setValue(requestID ?? UUID().uuidString, forHTTPHeaderField: "Idempotency-Key")
        request?.setValue(sdkVersion, forHTTPHeaderField: "X-SDK-VERSION")
        request?.setValue("Apphud \(platform) (\(self.sdkType) \(sdkVersion))", forHTTPHeaderField: "User-Agent")

        request?.timeoutInterval = defaultTimeout ?? (method == .get ? GET_TIMEOUT : POST_TIMEOUT)

        if method != .get {
            var finalParams: [String: Any] = ["api_key": apiKey]
            if params != nil {
                finalParams.merge(params!, uniquingKeysWith: {$1})
            }
            if let data = try? JSONSerialization.data(withJSONObject: finalParams, options: [.prettyPrinted]) {
                request?.httpBody = data
            }
        }

        if ApphudUtils.shared.logLevel == .all {
            var string: String = ""
            if let data = request?.httpBody, let str = String(data: data, encoding: .utf8) {
                string = str
            }
            apphudLog("Start \(method) request \(request?.url?.absoluteString ?? "") timeout:\(String(request?.timeoutInterval ?? 0)) params: \(string)", logLevel: .all)
        } else {
            apphudLog("Start \(method) request \(request?.url?.absoluteString ?? "")")
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

    private func start(request: URLRequest, useDecoder: Bool = false, retries: Int, delay: TimeInterval) async -> ApphudHTTPResponse {

        let startDate = Date()
        let method = request.httpMethod ?? ""

        do {
            let result: (Data, URLResponse, Int)
            if retries > 0 {
                result = try await URLSession.shared.data(for: request, retries: retries, delay: delay)
            } else {
                let resp = try await URLSession.shared.data(for: request)
                result = (resp.0, resp.1, 1)
            }

            guard let httpResponse = result.1 as? HTTPURLResponse else {
                return (false, nil, nil, nil, NSURLErrorUnknown, 0, 1)
            }

            let apphudResponse: ApphudParsedResponse = parseResponse(request: request, httpResponse: httpResponse, data: result.0, parseJson: !useDecoder || apphudIsSandbox())

            let requestDuration = Date().timeIntervalSince(startDate)

            let finalHttpResponse: ApphudHTTPResponse = (apphudResponse.0, apphudResponse.1, apphudResponse.2, apphudResponse.3, apphudResponse.4, requestDuration, result.2)

            return finalHttpResponse

        } catch {
            let apphudError = error as? ApphudError
            let attempts = apphudError?.attempts ?? retries

            let code = (error as NSError?)?.code ?? NSURLErrorUnknown

            if ApphudUtils.shared.logLevel == .all {
                apphudLog("Request \(method) \(request.url?.absoluteString ?? "") failed with code: \(code) after: \(attempts) attempts error: \(error.localizedDescription)", logLevel: .all)
            } else {
                apphudLog("Request \(method) \(request.url?.absoluteString ?? "") failed with code: \(code) after: \(attempts) attempts error: \(error.localizedDescription)")
            }

            // Handle any errors that occurred during the request
            return (false, nil, nil, error, code, 0, attempts)
        }
    }

    private func parseResponse(request: URLRequest, httpResponse: HTTPURLResponse, data: Data, parseJson: Bool) -> ApphudParsedResponse {

        let method = request.httpMethod ?? ""
        let code = httpResponse.statusCode

        let dictionary: [String: Any]?
        if parseJson {
            dictionary = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } else {
            dictionary = nil
        }

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
            return (true, dictionary, data, nil, code)
        }

        if ApphudUtils.shared.logLevel == .all {
            apphudLog("Request \(method) \(request.url?.absoluteString ?? "") failed with code: \(code)", logLevel: .all)
        } else {
            apphudLog("Request \(method) \(request.url?.absoluteString ?? "") failed with code: \(code)")
        }

        if code == 422 && dictionary != nil {
            let modifiedError = self.parseError(dictionary!)
            return (false, nil, data, modifiedError, code)
        } else {
            let error = ApphudError(message: "HTTP Request Failed")
            return (false, nil, data, error, code)
        }
    }

    private func parseError(_ dictionary: [String: Any]) -> Error? {
        if let errors = dictionary["errors"] as? [[String: Any]], let errorDict = errors.first, let errorMessage = errorDict["title"] as? String {
            let idString = errorDict["id"] as? String
            
            return ApphudError(message: (idString ?? "") + " " + errorMessage)
        } else {
            return nil
        }
    }
}
