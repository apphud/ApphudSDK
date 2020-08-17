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
        if increment {
            if value != nil {
                return [key: value, "increment": increment, "set_once": setOnce, "kind": type]
            }
        } else {
            if value != nil {
                return [key: value, "set_once": setOnce, "kind": type]
            } else {
                return [key: value, "set_once": setOnce]
            }
        }
        return nil
    }
}
