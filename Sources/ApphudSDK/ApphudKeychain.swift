//
//  ApphudKeychain.swift
//  Apphud
//
//  Created by ren6 on 30/05/2019.
//  Copyright © 2019 Softeam Inc. All rights reserved.
//

import UIKit
import Security

// Constant Identifiers
let userAccount = "ApphudUser"
let accessGroup = "SecuritySerivice"
let deviceIdKey : NSString = "ApphudDeviceID"

// Arguments for the keychain queries
let kSecClassValue = NSString(format: kSecClass)
let kSecAttrAccountValue = NSString(format: kSecAttrAccount)
let kSecValueDataValue = NSString(format: kSecValueData)
let kSecClassGenericPasswordValue = NSString(format: kSecClassGenericPassword)
let kSecAttrServiceValue = NSString(format: kSecAttrService)
let kSecMatchLimitValue = NSString(format: kSecMatchLimit)
let kSecReturnDataValue = NSString(format: kSecReturnData)
let kSecMatchLimitOneValue = NSString(format: kSecMatchLimitOne)

internal class ApphudKeychain: NSObject {
    
    internal class func generateUUID() -> String{
        let uuid = NSUUID.init().uuidString
        return uuid
    }
    
    internal class func loadDeviceID() -> String? {
        return self.load(deviceIdKey)
    }
    
    internal class func saveDeviceID(deviceID : String) {
        self.save(deviceIdKey, data: deviceID)
    }
    
    private class func save(_ service: NSString, data: String) {
        if let dataFromString = data.data(using: .utf8, allowLossyConversion: false) {
            
            let keychainQuery : NSMutableDictionary = [
                kSecClassValue : kSecClassGenericPasswordValue,
                kSecAttrServiceValue : service,
                kSecAttrAccountValue : userAccount,
                kSecValueDataValue : dataFromString,
                NSString(format: kSecAttrAccessible)  : NSString(format: kSecAttrAccessibleAfterFirstUnlock),
            ]
            
            SecItemDelete(keychainQuery as CFDictionary)
            SecItemAdd(keychainQuery as CFDictionary, nil)
        }        
    }
    
    private class func load(_ service: NSString) -> String? {
        let keychainQuery: NSMutableDictionary = NSMutableDictionary(objects: [kSecClassGenericPasswordValue, service, userAccount, kCFBooleanTrue!, kSecMatchLimitOneValue], forKeys: [kSecClassValue, kSecAttrServiceValue, kSecAttrAccountValue, kSecReturnDataValue, kSecMatchLimitValue])
        
        var dataTypeRef :AnyObject?
        
        let status: OSStatus = SecItemCopyMatching(keychainQuery, &dataTypeRef)
        var contentsOfKeychain: String? = nil
        
        if status == errSecSuccess {
            if let retrievedData = dataTypeRef as? Data {
                contentsOfKeychain = String(data: retrievedData, encoding: .utf8)
            }
        }
        return contentsOfKeychain
    }
}
