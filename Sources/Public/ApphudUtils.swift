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

    // Should not be used directly by developer
    @objc public class func useStoreKitV2() {
        shared.useStoreKitV2 = true
    }

    public static func checkRules() {
        ApphudInternal.shared.checkForUnreadNotifications()
    }

    public static func sdkVersion() -> String {
        apphud_sdk_version
    }

    internal static let shared = ApphudUtils()
    private(set) var logLevel: ApphudLogLevel = .off
    internal var storeKitObserverMode = false
    internal var optOutOfTracking = false
    private(set) var useStoreKitV2 = false

    /**
     When `true`, duplicates console logs to `Caches/logs.txt`.
     The file is cleared once per app launch on the first logged message.
     Read logs at runtime via ``logFileURL`` or ``readLogs()``.
     */
    public var saveLogsToFile = false
    public static func enableWriteLogsToFile() {
        shared.saveLogsToFile = true
    }

    /**
     URL of the log file in the app's Caches directory, or `nil` if unavailable.
     */
    public static var logFileURL: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first?
            .appendingPathComponent("logs.txt")
    }

    /**
     Returns the current contents of the log file, or an empty string if the file is missing or unreadable.
     */
    public static func readLogs() -> String {
        guard let url = logFileURL,
              let data = try? Data(contentsOf: url),
              let contents = String(data: data, encoding: .utf8) else {
            return ""
        }
        return contents
    }

    fileprivate static let logFileQueue = DispatchQueue(label: "com.apphud.logs")
    private static var logFileClearedThisSession = false

    fileprivate func appendLogToFile(_ line: String) {
        guard saveLogsToFile, let url = Self.logFileURL else { return }
        Self.logFileQueue.async {
            if !Self.logFileClearedThisSession {
                Self.logFileClearedThisSession = true
                if FileManager.default.fileExists(atPath: url.path) {
                    try? FileManager.default.removeItem(at: url)
                }
            }
            guard let data = (line + "\n").data(using: .utf8) else { return }
            if FileManager.default.fileExists(atPath: url.path) {
                guard let handle = try? FileHandle(forWritingTo: url) else { return }
                defer { try? handle.close() }
                _ = try? handle.seekToEnd()
                _ = try? handle.write(contentsOf: data)
            } else {
                try? data.write(to: url)
            }
        }
    }

    internal var isFlutter: Bool {
        ApphudHttpClient.shared.sdkType.lowercased() == "flutter"
    }
}

internal func apphudLog(_ text: String, forceDisplay: Bool = false) {
    apphudLog(text, logLevel: forceDisplay ? .off : .debug)
}

private func apphudFormattedLogLine(_ text: String) -> String {
    let formatter = DateFormatter()
    formatter.dateStyle = .none
    formatter.timeStyle = .medium
    let time = formatter.string(from: Date())
    return "[\(time)] [Apphud] \(text)"
}

internal func apphudLog(_ text: String, logLevel: ApphudLogLevel) {
    if ApphudUtils.shared.logLevel.rawValue >= logLevel.rawValue {
        let line = apphudFormattedLogLine(text)
        print(line)
        ApphudUtils.shared.appendLogToFile(line)
    }
}
