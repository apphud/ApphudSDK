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
     Returns the current session ID: the value the SDK puts in the `X-Apphud-Session-Id` header of API requests it builds from now on.

     After `setSessionId(_:)` accepts an ID, returns the ID from the latest accepted call in this app process; otherwise returns the SDK's own ID, which changes on app launch, when the app returns to the foreground after more than 30 minutes in the background (in AppKit macOS apps: after more than 30 minutes inactive; Mac Catalyst apps follow the background rule), and on `Apphud.logout()`.
     */
    var sessionId: String { get }

    /**
     Sets the session ID for a host SDK that owns the session. Every subsequent API request the SDK makes to Apphud carries this ID.

     Once an ID is accepted, the SDK stops starting sessions on its own: neither background nor `Apphud.logout()` changes the ID until another ID is accepted. The ID is not saved; after the app is relaunched the SDK starts its own sessions again until an ID is accepted.

     Call it before `Apphud.start(...)` so that customer registration already carries this ID; a later call affects only subsequent requests.

     - parameter sessionId: The session ID; surrounding whitespace is trimmed. A blank value or one with characters outside printable ASCII (line breaks, non-ASCII) is ignored and logged: the current session stays.
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
