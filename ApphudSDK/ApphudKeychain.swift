//
//  ApphudKeychain.swift
//  Apphud, Inc
//
//  Created by ren6 on 30/05/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import UIKit
import Security

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

public class ApphudKeychain: NSObject {

    internal class func generateUUID() -> String {
        let uuid = NSUUID.init().uuidString
        return uuid
    }

    internal class func loadDeviceID() -> String? {
        if let deviceID = UserDefaults.standard.value(forKey: defaultsDeviceIdKey) as? String, deviceID.count > 0 {
            return deviceID
        }
        return self.load(deviceIdKey)
    }

    internal class func loadUserID() -> String? {
        if let userID = UserDefaults.standard.value(forKey: defaultsUserIdKey) as? String, userID.count > 0 {
            return userID
        }
        return self.load(userIdKey)
    }

    internal class func resetValues() {
        saveUserID(userID: "")
        saveDeviceID(deviceID: "")
    }

    #if DEBUG
    public class func saveUserID(userID: String) {
        UserDefaults.standard.set(userID, forKey: defaultsUserIdKey)
        self.save(userIdKey, data: userID)
    }

    public class func saveDeviceID(deviceID: String) {
        UserDefaults.standard.set(deviceID, forKey: defaultsDeviceIdKey)
        self.save(deviceIdKey, data: deviceID)
    }
    #else
    internal class func saveUserID(userID: String) {
        UserDefaults.standard.set(userID, forKey: defaultsUserIdKey)
        self.save(userIdKey, data: userID)
    }

    internal class func saveDeviceID(deviceID: String) {
        UserDefaults.standard.set(deviceID, forKey: defaultsDeviceIdKey)
        self.save(deviceIdKey, data: deviceID)
    }
    #endif

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
