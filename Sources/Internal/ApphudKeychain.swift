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

/**
 The ids of identity version 1, kept as SDK 4.6 kept them: UserDefaults first, then the Keychain.
 Version 2 never takes its ids from here; it writes the reinstall key (see
 `ApphudKeychainKey.reinstall`), and its logout blanks the items of version 1.
 */
public class ApphudKeychain: NSObject {

    private static let userAccount = "ApphudUser"
    private static let deviceIdKey: NSString = "ApphudDeviceID"
    private static let userIdKey: NSString = "ApphudUserID"

    internal static let defaultsDeviceIdKey = "com.apphud.device_id"
    internal static let defaultsUserIdKey = "com.apphud.user_id"

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
                NSString(format: kSecClass): NSString(format: kSecClassGenericPassword),
                NSString(format: kSecAttrService): service,
                NSString(format: kSecAttrAccount): userAccount,
                NSString(format: kSecValueData): dataFromString,
                NSString(format: kSecAttrAccessible): NSString(format: kSecAttrAccessibleAfterFirstUnlock)
            ]

            SecItemDelete(keychainQuery as CFDictionary)
            SecItemAdd(keychainQuery as CFDictionary, nil)
        }
    }

    private class func load(_ service: NSString) -> String? {

        let keychainQuery: NSDictionary = [
            NSString(format: kSecClass): NSString(format: kSecClassGenericPassword),
            NSString(format: kSecAttrService): service,
            NSString(format: kSecAttrAccount): userAccount,
            NSString(format: kSecReturnData): kCFBooleanTrue!,
            NSString(format: kSecMatchLimit): NSString(format: kSecMatchLimitOne)
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

/// Keychain items the SDK reads or writes.
internal enum ApphudKeychainKey: String, CaseIterable {
    /// "This app was installed on this device before". Holds no id, survives a reinstall on the
    /// same device, never travels to another one, never removed on logout.
    case reinstall = "com.apphud.reinstall"
    /// Written by identity version 1 and old SDK versions. Version 2 never sends it or takes a reinstall
    /// from it (it only compares `ApphudDeviceID` with an old user id, see `ApphudIdentityStore.resolve`):
    /// it keeps it, so version 1 can come back to the same ids, and its logout blanks it.
    case legacyDeviceID = "ApphudDeviceID"
    case legacyUserID = "ApphudUserID"

    /// The protection class an item is written with. Version 1 deletes its items by the class old SDK
    /// versions used before it adds them again: an item of another class would block that for good.
    var accessible: CFString {
        self == .reinstall ? kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly : kSecAttrAccessibleAfterFirstUnlock
    }
}

/// One Keychain read. Any failure other than "no such item" is `unavailable`: a value that can't
/// be read must never pass for an absent one.
internal enum ApphudKeychainRead: Equatable {
    case found(String)
    case notFound
    case unavailable

    var isFound: Bool {
        if case .found = self { return true }
        return false
    }
}

internal protocol ApphudKeychainStoring {
    func read(_ key: ApphudKeychainKey) -> ApphudKeychainRead
    @discardableResult func write(_ key: ApphudKeychainKey, value: String) -> Bool
    func delete(_ key: ApphudKeychainKey)
}

internal struct ApphudSystemKeychain: ApphudKeychainStoring {

    // The account old SDK versions used; kept for every item.
    private static let account = "ApphudUser"

    private func query(_ key: ApphudKeychainKey) -> [CFString: Any] {
        [kSecClass: kSecClassGenericPassword,
         kSecAttrService: key.rawValue,
         kSecAttrAccount: Self.account]
    }

    func read(_ key: ApphudKeychainKey) -> ApphudKeychainRead {
        #if os(macOS)
        // Old SDK versions never used the Keychain on macOS.
        return .notFound
        #else
        var query = query(key)
        query[kSecReturnData] = kCFBooleanTrue
        query[kSecMatchLimit] = kSecMatchLimitOne

        var result: AnyObject?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        switch status {
        case errSecSuccess:
            // An old item blanked by logout holds "": it still counts as present.
            let value = (result as? Data).flatMap { String(data: $0, encoding: .utf8) } ?? ""
            return .found(value)
        case errSecItemNotFound:
            return .notFound
        default:
            return .unavailable
        }
        #endif
    }

    @discardableResult
    func write(_ key: ApphudKeychainKey, value: String) -> Bool {
        #if os(macOS)
        return true
        #else
        guard let data = value.data(using: .utf8) else { return false }
        SecItemDelete(query(key) as CFDictionary)
        var item = query(key)
        item[kSecValueData] = data
        item[kSecAttrAccessible] = key.accessible
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
        #endif
    }

    func delete(_ key: ApphudKeychainKey) {
        #if !os(macOS)
        SecItemDelete(query(key) as CFDictionary)
        #endif
    }
}
