//
//  FlowlessRequestManager.swift
//  flowless.me
//
//  Created by ren6 on 26/06/2019.
//  Copyright © 2019 flowless.me. All rights reserved.
//

import Foundation

internal struct FlowlessUserResponse<T: Decodable>: Decodable {
    var data: FlowlessUserResultsResponse<T>
}

internal struct FlowlessUserResultsResponse<T: Decodable>: Decodable {
    var results: T
}

internal struct FlowlessAPIDataResponse<T: Decodable>: Decodable {
    var data: T
}

internal struct FlowlessAPIArrayResponse<T: Decodable>: Decodable {
    var results: [T]
}

typealias FlowlessParsedResponse = (Bool, [String: Any]?, Data?, Error?, Int)
typealias FlowlessHTTPResponse = (Bool, [String: Any]?, Data?, Error?, Int, Double, Int)
typealias FlowlessHTTPResponseCallback = (Bool, [String: Any]?, Data?, Error?, Int, Double, Int) -> Void
typealias FlowlessStringCallback = (String?, Error?) -> Void
/**
 This is Flowless's internal class.
 */
public class FlowlessHttpClient {

    enum FlowlessHttpMethod: String {
        case post = "POST"
        case get = "GET"
        case put = "PUT"
    }

    enum FlowlessApiVersion: String {
        case APIV1 = "v1"
    }

    enum FlowlessEndpoint: Equatable {

        case macros

        var value: String {
            switch self {
            case .macros:
                return "macros"
            }
        }
    }

    static let productionEndpoint = "https://api.flowless.me"
    public var sdkType: String = "swift"
    public var sdkVersion: String = "0.1"

    public static let shared = FlowlessHttpClient()
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

    private let GET_TIMEOUT: TimeInterval = 10.0
    private let POST_TIMEOUT: TimeInterval = 20.0

    internal func requestInstance(url: URL) -> URLRequest? {
        var request = URLRequest(url: url)
        request.setValue(apiKey, forHTTPHeaderField: "Authorization")
        return request
    }

    internal func startRequest(path: FlowlessEndpoint, apiVersion: FlowlessApiVersion = .APIV1, params: [String: Any]?, method: FlowlessHttpMethod, useDecoder: Bool = false, retry: Bool = false, requestID: String? = nil, callback: FlowlessHTTPResponseCallback?) {

        if let request = makeRequest(path: path.value, apiVersion: apiVersion, params: params, method: method, requestID: requestID), !suspended {
            Task(priority: .userInitiated) {

                let retries: Int
                let retryDelay: TimeInterval

                if retry {
                    retries = 3
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

    private func makeRequest(path: String, apiVersion: FlowlessApiVersion, params: [String: Any]?, method: FlowlessHttpMethod, defaultTimeout: TimeInterval? = nil, requestID: String? = nil) -> URLRequest? {

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
        request?.setValue("Flowless \(platform) (\(self.sdkType) \(sdkVersion))", forHTTPHeaderField: "User-Agent")

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

    internal func start(request: URLRequest, callback: @escaping FlowlessStringCallback) {
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

    private func start(request: URLRequest, useDecoder: Bool = false, retries: Int, delay: TimeInterval) async -> FlowlessHTTPResponse {

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

            let FlowlessResponse: FlowlessParsedResponse = parseResponse(request: request, httpResponse: httpResponse, data: result.0, parseJson: !useDecoder || apphudIsSandbox())

            let requestDuration = Date().timeIntervalSince(startDate)

            let finalHttpResponse: FlowlessHTTPResponse = (FlowlessResponse.0, FlowlessResponse.1, FlowlessResponse.2, FlowlessResponse.3, FlowlessResponse.4, requestDuration, result.2)

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

    private func parseResponse(request: URLRequest, httpResponse: HTTPURLResponse, data: Data, parseJson: Bool) -> FlowlessParsedResponse {

        let method = request.httpMethod ?? ""
        let code = httpResponse.statusCode

        let dictionary: [String: Any]?
        if parseJson {
            dictionary = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any]
        } else {
            dictionary = nil
        }

        if let requestID = request.allHTTPHeaderFields?["Idempotency-Key"] as? String, let responseID = httpResponse.allHeaderFields["idempotency-key"] as? String ?? httpResponse.allHeaderFields["Idempotency-Key"] as? String, !requestID.isEmpty, !responseID.isEmpty, requestID != responseID {
            apphudLog("Invalid Response for \(String(describing: request.url))", logLevel: .all)
            let error = ApphudError(message: "Invalid HTTP Response")
            return (false, nil, data, error, 400)
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
