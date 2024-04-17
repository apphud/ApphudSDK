//
//  ApphudUserPropertyKey.swift
//  ApphudSDK
//
//  Created by Renat on 18.08.2020.
//

import Foundation

/**
 Built-in property keys.
 */
/** User email. Value must be String. */
public let _ApphudUserPropertyKeyEmail = "$email"

/** User name. Value must be String. */
public let _ApphudUserPropertyKeyName = "$name"

/** User phone number. Value must be String. */
public let _ApphudUserPropertyKeyPhone = "$phone"

/** User install cohort. Value must be String. */
public let _ApphudUserPropertyKeyCohort = "$cohort"

/** User email. Value must be Int. */
public let _ApphudUserPropertyKeyAge = "$age"

/** User email. Value must be one of: "male", "female", "other". */
public let _ApphudUserPropertyKeyGender = "$gender"

/**
 User property initializer class with reserved property names.
 */

@objc public class ApphudUserPropertyKey: NSObject {

    @objc public static var email: ApphudUserPropertyKey {
        .init(_ApphudUserPropertyKeyEmail)
    }

    @objc public static var age: ApphudUserPropertyKey {
        .init(_ApphudUserPropertyKeyAge)
    }

    @objc public static var phone: ApphudUserPropertyKey {
        .init(_ApphudUserPropertyKeyPhone)
    }

    @objc public static var name: ApphudUserPropertyKey {
        .init(_ApphudUserPropertyKeyName)
    }

    @objc public static var gender: ApphudUserPropertyKey {
        .init(_ApphudUserPropertyKeyGender)
    }

    @objc public static var cohort: ApphudUserPropertyKey {
        .init(_ApphudUserPropertyKeyCohort)
    }

    /**
     Initialize with custom property key string.
     Example:
     ````
     Apphud.setUserProperty(key: .init("custom_prop_1"), value: 0.5)
     ````
     */
    @objc public init(_ key: String) {
        self.key = key
    }

    internal let key: String
}
