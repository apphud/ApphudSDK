//
//  ApphudSession.swift
//  ApphudSDK
//
//  Created by Valery Levshin on 23.09.2026.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif
#if os(macOS)
import AppKit
#endif
#if os(watchOS)
import WatchKit
#endif

/// Client-side session. Its id is sent as the `X-Apphud-Session-Id` header on every
/// request built by `ApphudHttpClient.requestInstance(url:)`.
///
/// Default mode, one rule for every launch (the user's or a background one) and every
/// return to the foreground: the session continues if the app went to the background at most
/// 30 minutes ago, otherwise a new one starts. The launch rule runs at `Apphud.start`; a session
/// it starts counts as being in the background since then, until the app is in the foreground
/// (at once when `Apphud.start` runs in an active app). `logout()` starts a new session. External mode (`Apphud.platform.setSessionId(_:)`): the host owns every boundary
/// until the process ends, and nothing is saved.
///
/// Guarded by a lock rather than an actor: `requestInstance(url:)` and
/// `PlatformProtocol.sessionId` read the id synchronously and off the main actor.
internal final class ApphudSession: @unchecked Sendable {

    // Replaced in tests only. `ApphudInternal.initialize` touches it first, so the launch rule
    // and lifecycle observers start with `Apphud.start`, not at the first request.
    internal static var shared = ApphudSession()

    internal static let headerName = "X-Apphud-Session-Id"
    internal static let backgroundTimeout: TimeInterval = 30 * 60

    private static let idKey = "ApphudSessionId"
    private static let lastBackgroundDateKey = "ApphudSessionLastBackgroundDate"

    private let lock = NSLock()
    // UserDefaults posts didChangeNotification synchronously inside set(), and a host
    // observer may call into the SDK there (every request reads the id): writes never run
    // under `lock`. They are queued while holding it, so they reach UserDefaults in order.
    private let writeQueue = DispatchQueue(label: "com.apphud.session.defaults")
    private let defaults: UserDefaults
    private let now: () -> Date
    // False while UserDefaults can't be read (before the first unlock after a reboot): it then
    // reads empty, and writing would overwrite the real values.
    private let canPersist: () -> Bool
    private var observers: [NSObjectProtocol] = []

    private var id: String
    private var isExternal = false
    // When the app went to the background, while it is there.
    private var backgroundStartDate: Date?

    init(defaults: UserDefaults = .standard,
         now: @escaping () -> Date = { Date() },
         notificationCenter: NotificationCenter = .default,
         canPersist: (() -> Bool)? = nil) {
        self.defaults = defaults
        self.now = now
        let canPersist = canPersist ?? { [defaults] in Self.isStorageReadable(defaults, protectedDataAvailable: Self.isProtectedDataAvailable) }
        self.canPersist = canPersist
        let launchDate = now()

        let persistable = canPersist()
        if persistable,
           let savedId = defaults.string(forKey: Self.idKey),
           let lastBackground = defaults.object(forKey: Self.lastBackgroundDateKey) as? Date,
           case let elapsed = launchDate.timeIntervalSince(lastBackground),
           elapsed >= 0, elapsed <= Self.backgroundTimeout {
            // Continues the saved session and keeps its background time, so launches never
            // extend it.
            self.id = savedId
            self.backgroundStartDate = lastBackground
        } else {
            // A new session, in the background since launch until the app becomes active.
            let id = Self.makeId()
            self.id = id
            self.backgroundStartDate = launchDate
            if persistable { persist(id: id, backgroundDate: launchDate) }
        }
        observeLifecycle(notificationCenter)
    }

    internal var sessionId: String {
        lock.lock(); defer { lock.unlock() }
        return id
    }

    internal func didEnterBackground() {
        let date = now()
        let persistable = canPersist()
        lock.lock(); defer { lock.unlock() }
        // The first notification wins: the app has been in background since then.
        guard backgroundStartDate == nil else { return }
        backgroundStartDate = date
        guard !isExternal, persistable else { return }
        persist(id: id, backgroundDate: date)
    }

    /// The app is coming to the foreground or became active; the first signal after the
    /// background wins.
    internal func willEnterForeground() {
        let date = now()
        let persistable = canPersist()
        lock.lock(); defer { lock.unlock() }
        guard let start = backgroundStartDate else { return }
        backgroundStartDate = nil
        guard !isExternal, date.timeIntervalSince(start) > Self.backgroundTimeout else { return }
        startNewSession(persistable: persistable)
    }

    /// `Apphud.start` may run when the app is already active (a late start, as in the Flutter and
    /// React Native plugins): its foreground signal has passed, so it is taken now.
    internal func takeForeground(ifActive isActive: Bool) {
        if isActive { willEnterForeground() }
    }

    @MainActor internal static func isAppActive() -> Bool {
        #if os(iOS) || os(tvOS) || os(visionOS)
        return UIApplication.shared.applicationState == .active
        #elseif os(watchOS)
        return WKApplication.shared().applicationState == .active
        #elseif os(macOS)
        // `NSApp`, not `NSApplication.shared`: a start before NSApplicationMain must not create it.
        return NSApp?.isActive ?? false
        #endif
    }

    /// `logout()` boundary; ignored in external mode.
    internal func startNewSessionOnLogout() {
        let persistable = canPersist()
        lock.lock(); defer { lock.unlock() }
        guard !isExternal else { return }
        startNewSession(persistable: persistable)
    }

    /// Host-owned session id. A blank value or one that can't be an HTTP header value is
    /// ignored: the session stays as it is. The host id is never saved.
    internal func setExternalSessionId(_ value: String) {
        let hostId = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !hostId.isEmpty, hostId.unicodeScalars.allSatisfy({ (0x20...0x7E).contains($0.value) }) else {
            apphudLog("setSessionId ignored: invalid session id", forceDisplay: true)
            return
        }
        lock.lock(); defer { lock.unlock() }
        isExternal = true
        id = hostId
    }

    /// Background, then every signal that the app is in the foreground: coming back from the
    /// background, and becoming active (a cold launch doesn't post willEnterForeground in
    /// every app).
    internal static var lifecycleNotificationNames: (background: Notification.Name, foreground: [Notification.Name]) {
        #if os(iOS) || os(tvOS) || os(visionOS)
        (UIApplication.didEnterBackgroundNotification,
         [UIApplication.willEnterForegroundNotification, UIApplication.didBecomeActiveNotification])
        #elseif os(watchOS)
        (WKApplication.didEnterBackgroundNotification,
         [WKApplication.willEnterForegroundNotification, WKApplication.didBecomeActiveNotification])
        #elseif os(macOS)
        // macOS has no background state: an inactive app counts as backgrounded.
        (NSApplication.didResignActiveNotification, [NSApplication.didBecomeActiveNotification])
        #endif
    }

    /// UserDefaults is readable once it returns the saved session, or while protected data is
    /// available.
    internal static func isStorageReadable(_ defaults: UserDefaults, protectedDataAvailable: () -> Bool) -> Bool {
        defaults.object(forKey: idKey) != nil || protectedDataAvailable()
    }

    /// Off the main thread it can't be read and counts as unavailable.
    private static func isProtectedDataAvailable() -> Bool {
        #if os(iOS) || os(tvOS) || os(visionOS)
        guard Thread.isMainThread else { return false }
        return MainActor.assumeIsolated { UIApplication.shared.isProtectedDataAvailable }
        #else
        return true
        #endif
    }

    // MARK: - Private

    /// Tests only: waits until queued writes reach UserDefaults.
    internal func waitForPendingWrites() {
        writeQueue.sync {}
    }

    // The caller holds the lock.
    private func startNewSession(persistable: Bool) {
        id = Self.makeId()
        if persistable { persist(id: id, backgroundDate: nil) }
    }

    // The caller holds the lock, or is the initializer.
    private func persist(id: String, backgroundDate: Date?) {
        writeQueue.async { [defaults] in
            defaults.set(id, forKey: Self.idKey)
            if let backgroundDate { defaults.set(backgroundDate, forKey: Self.lastBackgroundDateKey) }
        }
    }

    private static func makeId() -> String {
        UUID().uuidString.lowercased()
    }

    private func observeLifecycle(_ center: NotificationCenter) {
        let names = Self.lifecycleNotificationNames
        observers.append(center.addObserver(forName: names.background, object: nil, queue: nil) { [weak self] _ in
            self?.didEnterBackground()
        })
        for name in names.foreground {
            observers.append(center.addObserver(forName: name, object: nil, queue: nil) { [weak self] _ in
                self?.willEnterForeground()
            })
        }
    }
}
