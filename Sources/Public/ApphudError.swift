//
//  ApphudError.swift
//  Apphud, Inc
//
//  Created by ren6 on 31.05.2020.
//  Copyright © 2020 Apphud Inc. All rights reserved.
//

import Foundation

/**
 Custom Apphud wrapper around NSError.
 */
public let APPHUD_ERROR_NO_INTERNET = -999
public let APPHUD_NO_PRODUCTS = -998
public let APPHUD_DEFAULT_RETRIES: Int = 3
public let APPHUD_MAX_INITIAL_LOAD_TIME: TimeInterval = 10.0
public let APPHUD_INFINITE_RETRIES: Int = 999_999

public class ApphudError: NSError, @unchecked Sendable {

    private let codeDomain = "com.apphud.error"

    var attempts: Int?
    
    public func networkIssue() -> Bool {
        let noInternetErrors = [NSURLErrorNotConnectedToInternet, NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost, APPHUD_ERROR_NO_INTERNET]
        return noInternetErrors.contains(code)
    }
    
    init(message: String, code: Int = 0) {
        super.init(domain: codeDomain, code: code, userInfo: [NSLocalizedDescriptionKey: message])
    }

    init(error: Error) {
        super.init(domain: (error as NSError).domain, code: (error as NSError).code, userInfo: [NSLocalizedDescriptionKey: (error as NSError).localizedDescription])
    }
    
    init(httpErrorCode: Int, attempts: Int) {
        super.init(domain: codeDomain, code: httpErrorCode, userInfo: [NSLocalizedDescriptionKey: "HTTP Request Failed"])
        self.attempts = attempts
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}

extension NSError {
    var apphudUnderlyingErrorCode: Int {

        if let error = userInfo["NSUnderlyingError"] as? NSError {
            return error.code
        }

        return -1
    }

    var apphudUnderlyingErrorDescription: String? {

        if let error = userInfo["NSUnderlyingError"] as? NSError {
            return error.localizedFailureReason
        }

        return nil
    }
}
