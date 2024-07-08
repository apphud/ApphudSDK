//
//  ApphudURLSession.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 17.11.2023.
//

import Foundation

extension URLSession {

    func data(for request: URLRequest, retries: Int, delay: TimeInterval) async throws -> (Data, URLResponse, Int) {

        if retries == 0 && delay == 0 {
            let response = try await data(for: request)
            return (response.0, response.1, 1)
        }

        for attempt in 1...retries {
            do {
                let (data, response) = try await self.data(for: request)
                if let httpResponse = response as? HTTPURLResponse,
                   500...599 ~= httpResponse.statusCode {
                    // If server error (500+ status codes) and it's not the last attempt, then wait and retry
                    if attempt < retries {

                        apphudLog("Request \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "") failed with code: \(httpResponse.statusCode) attempt \(attempt)/\(retries), trying again..")

                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000)) // Sleep expects nanoseconds
                        continue
                    } else {
                        throw ApphudError(httpErrorCode: httpResponse.statusCode, attempts: attempt)
                    }
                }
                return (data, response, attempt)

            } catch {
                let nsError: NSError = error as NSError
                let urlError: URLError? = error as? URLError

                let nsErrorCode = nsError.code

                let serverIsUnreachable = [NSURLErrorCannotConnectToHost, NSURLErrorTimedOut, 500, 502, 503].contains(nsErrorCode)
                let urlNetworkUnavailable = urlError?.networkUnavailableReason != nil
                let errorUnknown = NSURLErrorUnknown == nsErrorCode

                if serverIsUnreachable || urlNetworkUnavailable || errorUnknown {
                    // If a network issue (like timeout) and it's not the last attempt, then wait and retry
                    if attempt < retries {

                        apphudLog("Request \(request.httpMethod ?? "") \(request.url?.absoluteString ?? "") failed with code: \(nsErrorCode) attempt \(attempt)/\(retries), trying again..")

                        try await Task.sleep(nanoseconds: UInt64(delay * 1_000_000_000))
                        continue
                    } else {
                        throw ApphudError(httpErrorCode: nsErrorCode, attempts: attempt)
                    }
                } else {
                    throw ApphudError(httpErrorCode: nsErrorCode, attempts: attempt)
                }
            }
        }

        throw ApphudError(httpErrorCode: 0, attempts: retries)
    }
}
