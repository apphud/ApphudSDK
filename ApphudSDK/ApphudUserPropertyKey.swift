//
//  ApphudUserPropertyKey.swift
//  ApphudSDK
//
//  Created by Renat on 18.08.2020.
//

import UIKit

/**
 Built-in property keys.
 */
/** User email. Value must be String. */
public let ApphudUserPropertyKeyEmail = "$email"

/** User name. Value must be String. */
public let ApphudUserPropertyKeyName = "$name"

/** User phone number. Value must be String. */
public let ApphudUserPropertyKeyPhone = "$phone"

/** User install cohort. Value must be String. */
public let ApphudUserPropertyKeyCohort = "$cohort"

/** User email. Value must be Int. */
public let ApphudUserPropertyKeyAge = "$age"

/** User email. Value must be one of: "male", "female", "other". */
public let ApphudUserPropertyKeyGender = "$gender"

@objc public class ApphudUserPropertyKey: NSObject {

    @objc public static var email: ApphudUserPropertyKey {
        .init(ApphudUserPropertyKeyEmail)
    }

    @objc public static var age: ApphudUserPropertyKey {
        .init(ApphudUserPropertyKeyAge)
    }

    @objc public static var phone: ApphudUserPropertyKey {
        .init(ApphudUserPropertyKeyPhone)
    }

    @objc public static var name: ApphudUserPropertyKey {
        .init(ApphudUserPropertyKeyName)
    }

    @objc public static var gender: ApphudUserPropertyKey {
        .init(ApphudUserPropertyKeyGender)
    }

    @objc public static var cohort: ApphudUserPropertyKey {
        .init(ApphudUserPropertyKeyCohort)
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
