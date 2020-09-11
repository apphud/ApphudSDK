//
//  ApphudUtils.swift
//  subscriptionstest
//
//  Created by ren6 on 12/07/2019.
//  Copyright © 2019 apphud. All rights reserved.
//

import Foundation

enum ApphudLogLevel: Int {
    case off = 0
    case debug = 1
    case all = 2
}

/**
 This class will contain some utils, more will be added in the future.
 */
public class ApphudUtils: NSObject {

    /**
     Disables console logging.
    */
    @objc public class func enableDebugLogs() {
        shared.logLevel = .debug
    }

    @objc public class func enableAllLogs() {
        shared.logLevel = .all
    }

    internal static let shared = ApphudUtils()
    private(set) var logLevel: ApphudLogLevel = .off
    internal var storeKitObserverMode = false
    internal var optOutOfIDFACollection = false
}

internal func apphudLog(_ text: String, forceDisplay: Bool = false) {
    apphudLog(text, logLevel: forceDisplay ? .off : .debug)
}

internal func apphudLog(_ text: String, logLevel: ApphudLogLevel) {
    if  ApphudUtils.shared.logLevel.rawValue >= logLevel.rawValue {
        let formatter = DateFormatter()
        formatter.dateStyle = .none
        formatter.timeStyle = .medium
        let time = formatter.string(from: Date())
        print("[\(time)] [Apphud] \(text)")
    }
}
