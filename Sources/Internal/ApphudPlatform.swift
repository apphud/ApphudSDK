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

    /**
     Current session ID sent in the `X-Apphud-Session-Id` header: the one from `setSessionId(_:)`, or the SDK's own.
     */
    var sessionId: String { get }

    /**
     Sets the session ID for all subsequent requests; the SDK stops rotating sessions until the app restarts.
     */
    func setSessionId(_ sessionId: String)
}

internal struct ApphudPlatform: PlatformProtocol {
    func setUserProperty(key: some PlatformUserPropertyKeyDescribing, value: Any?, setOnce: Bool) {
        ApphudInternal.shared.setUserProperty(key: .init(key.name), value: value, setOnce: setOnce, increment: false,
                                              attributes: key.attributes)
    }

    var sessionId: String {
        return ApphudSession.shared.sessionId
    }

    func setSessionId(_ sessionId: String) {
        ApphudSession.shared.setExternalSessionId(sessionId)
    }
}

extension Apphud {
    internal static var platform: any PlatformProtocol { ApphudPlatform() }
}
