//
//  ApphudPlatform.swift
//  ApphudSDK
//

import Foundation

/**
 A user property key with extra attributes sent alongside the property.
 */
internal protocol PlatformUserPropertyKeyDescribing {
    var name: String { get }
    var attributes: [String: String] { get }
}

internal protocol PlatformProtocol {
    /**
     Sets a user property whose key carries extra attributes. Otherwise behaves like
     ``Apphud/setUserProperty(key:value:setOnce:)``.
     */
    func setUserProperty(key: some PlatformUserPropertyKeyDescribing, value: Any?, setOnce: Bool)
}

internal struct ApphudPlatform: PlatformProtocol {
    func setUserProperty(key: some PlatformUserPropertyKeyDescribing, value: Any?, setOnce: Bool) {
        ApphudInternal.shared.setUserProperty(key: .init(key.name), value: value, setOnce: setOnce, increment: false,
                                              attributes: key.attributes)
    }
}

extension Apphud {
    internal static var platform: any PlatformProtocol { ApphudPlatform() }
}
