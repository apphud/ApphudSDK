//
//  ApphudError.swift
//  Apphud, Inc
//
//  Created by ren6 on 31.05.2020.
//  Copyright © 2020 Apphud Inc. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#endif
import Foundation

/**
 Custom Apphud wrapper around NSError.
 */

public class ApphudError: NSError {

    private let codeDomain = "com.apphud.error"

    init(message: String) {
        super.init(domain: codeDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: message])
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
