//
//  ApphudUserProperty.swift
//  ApphudSDK
//
//  Created by Renat on 15.08.2020.
//

import UIKit

struct ApphudUserProperty {
    let key: String
    let value: Any?
    let increment: Bool
    let setOnce: Bool
    let type: String
    func toJSON() -> [String: Any?]? {

        if increment && value == nil {return nil}

        var modifiedValue = value

        if value is Float, let doubleValue = value as? Double {
            modifiedValue = Decimal(doubleValue)
        } else if value is Double, let doubleValue = value as? Double {
            modifiedValue = Decimal(doubleValue)
        }

        var jsonParams: [String: Any?] = ["name": key, "value": modifiedValue, "set_once": setOnce]

        if value != nil {
            jsonParams["kind"] = type
        }

        if increment {
            jsonParams["increment"] = increment
        }

        return jsonParams
    }
}
