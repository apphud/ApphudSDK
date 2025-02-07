//
//  ApphudKeychain.swift
//  Apphud, Inc
//
//  Created by ren6 on 30/05/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import Security
import Foundation
#if canImport(UIKit)
import UIKit
#endif

// Constant Identifiers
let userAccount = "ApphudUser"
let accessGroup = "SecuritySerivice"
let deviceIdKey: NSString = "ApphudDeviceID"
let userIdKey: NSString = "ApphudUserID"

let defaultsDeviceIdKey = "com.apphud.device_id"
let defaultsUserIdKey = "com.apphud.user_id"

// Arguments for the keychain queries
let kSecClassValue = NSString(format: kSecClass)
let kSecAttrAccountValue = NSString(format: kSecAttrAccount)
let kSecValueDataValue = NSString(format: kSecValueData)
let kSecClassGenericPasswordValue = NSString(format: kSecClassGenericPassword)
let kSecAttrServiceValue = NSString(format: kSecAttrService)
let kSecMatchLimitValue = NSString(format: kSecMatchLimit)
let kSecReturnDataValue = NSString(format: kSecReturnData)
let kSecMatchLimitOneValue = NSString(format: kSecMatchLimitOne)
/**
 Class for storing user data
 */

public class ApphudKeychain: NSObject {

    @MainActor
    internal static var canUseKeychain: Bool {
    #if os(iOS) || os(tvOS)
        return UIApplication.shared.isProtectedDataAvailable
    #elseif os(macOS)
        return false
    #else
        return true
    #endif
    }

    @MainActor
    internal static var hasLocalStorageData: Bool {
        loadDeviceID(onlyFromDefaults: true) != nil && loadUserID(onlyFromDefaults: true) != nil
    }

    internal class func generateUUID() -> String {
        let uuid = NSUUID.init().uuidString
        return uuid
    }

    @MainActor
    internal class func loadDeviceID(onlyFromDefaults: Bool = false) -> String? {
        if let deviceID = UserDefaults.standard.value(forKey: defaultsDeviceIdKey) as? String, deviceID.count > 0 {
            return deviceID
        }

        if canUseKeychain && !onlyFromDefaults {
            return self.load(deviceIdKey)
        } else {
            return nil
        }
    }

    @MainActor
    internal class func loadUserID(onlyFromDefaults: Bool = false) -> String? {
        if let userID = UserDefaults.standard.value(forKey: defaultsUserIdKey) as? String, userID.count > 0 {
            return userID
        }
        if canUseKeychain && !onlyFromDefaults {
            return self.load(userIdKey)
        } else {
            return nil
        }
    }

    @MainActor
    internal class func resetValues() {
        if canUseKeychain {
            saveUserID(userID: "")
            saveDeviceID(deviceID: "")
        }
    }

    @MainActor
    internal class func saveUserID(userID: String) {
        UserDefaults.standard.set(userID, forKey: defaultsUserIdKey)
        if canUseKeychain {
            self.save(userIdKey, data: userID)
        }
    }

    @MainActor
    internal class func saveDeviceID(deviceID: String) {
        UserDefaults.standard.set(deviceID, forKey: defaultsDeviceIdKey)
        if canUseKeychain {
            self.save(deviceIdKey, data: deviceID)
        }
    }

    private class func save(_ service: NSString, data: String) {
        if let dataFromString = data.data(using: .utf8, allowLossyConversion: false) {

            let keychainQuery: NSDictionary = [
                kSecClassValue: kSecClassGenericPasswordValue,
                kSecAttrServiceValue: service,
                kSecAttrAccountValue: userAccount,
                kSecValueDataValue: dataFromString,
                NSString(format: kSecAttrAccessible): NSString(format: kSecAttrAccessibleAfterFirstUnlock)
            ]

            SecItemDelete(keychainQuery as CFDictionary)
            SecItemAdd(keychainQuery as CFDictionary, nil)
        }
    }

    private class func load(_ service: NSString) -> String? {

        let keychainQuery: NSDictionary = [
            kSecClassValue: kSecClassGenericPasswordValue,
            kSecAttrServiceValue: service,
            kSecAttrAccountValue: userAccount,
            kSecReturnDataValue: kCFBooleanTrue!,
            kSecMatchLimitValue: kSecMatchLimitOneValue
        ]

        var dataTypeRef: AnyObject?

        let status: OSStatus = SecItemCopyMatching(keychainQuery, &dataTypeRef)
        var contentsOfKeychain: String?

        if status == errSecSuccess {
            if let retrievedData = dataTypeRef as? Data {
                contentsOfKeychain = String(data: retrievedData, encoding: .utf8)
            }
        }

        guard contentsOfKeychain?.count ?? 0 > 0 else {return nil}

        return contentsOfKeychain
    }
}
