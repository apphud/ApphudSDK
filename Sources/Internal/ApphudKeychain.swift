//
//  ApphudKeychain.swift
//  Apphud, Inc
//
//  Created by ren6 on 30/05/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import Security
import Foundation

/**
 Kept for source compatibility. The SDK no longer keeps ids in the Keychain: the only item it
 writes is the reinstall key, see `ApphudKeychainKey.reinstall`.
 */
public class ApphudKeychain: NSObject {}

/// Keychain items the SDK reads or writes.
internal enum ApphudKeychainKey: String, CaseIterable {
    /// "This app was installed on this device before". Holds no id, survives a reinstall on the
    /// same device, never travels to another one, never removed on logout.
    case reinstall = "com.apphud.reinstall"
    /// Written by old SDK versions. Read once to tell a reinstall, never to adopt an id, then deleted.
    case legacyDeviceID = "ApphudDeviceID"
    case legacyUserID = "ApphudUserID"
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
        item[kSecAttrAccessible] = kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly
        return SecItemAdd(item as CFDictionary, nil) == errSecSuccess
        #endif
    }

    func delete(_ key: ApphudKeychainKey) {
        #if !os(macOS)
        SecItemDelete(query(key) as CFDictionary)
        #endif
    }
}
