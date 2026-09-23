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
/// Default mode: a new session starts on launch (the first access in the process), on
/// return to the foreground after more than 30 minutes in the background, and on
/// `logout()`. External mode (`Apphud.setSessionId(_:)`): the host owns every boundary
/// until the process ends.
///
/// Guarded by a lock rather than an actor: `requestInstance(url:)` reads the id
/// synchronously and off the main actor.
internal final class ApphudSession: @unchecked Sendable {

    // Replaced in tests only.
    internal static var shared: ApphudSession = {
        let session = ApphudSession()
        session.checkBackgroundLaunch()
        return session
    }()

    internal static let headerName = "X-Apphud-Session-Id"
    internal static let backgroundTimeout: TimeInterval = 30 * 60

    private static let numberKey = "ApphudSessionNumber"
    private static let lastBackgroundDateKey = "ApphudSessionLastBackgroundDate"

    private let lock = NSLock()
    // UserDefaults posts didChangeNotification synchronously inside set(), and a host
    // observer may read `Apphud.sessionId` there: writes never run under `lock`. They are
    // queued while holding it, so they reach UserDefaults in order.
    private let writeQueue = DispatchQueue(label: "com.apphud.session.defaults")
    private let defaults: UserDefaults
    private let now: () -> Date
    private let launchDate: Date
    private var observers: [NSObjectProtocol] = []

    private var id: String
    private var number: Int
    private var isExternal = false
    // Background start in this process only: launch already starts a new session, so the
    // date persisted by a previous process is never compared.
    private var backgroundStartDate: Date?

    init(defaults: UserDefaults = .standard,
         now: @escaping () -> Date = { Date() },
         notificationCenter: NotificationCenter = .default) {
        self.defaults = defaults
        self.now = now
        self.launchDate = now()
        // Launch boundary. Before the first unlock after a reboot (prewarming, background
        // launch) UserDefaults reads empty, so the number may restart from 1.
        self.id = Self.makeId()
        self.number = defaults.integer(forKey: Self.numberKey) + 1
        persistNumber()
        observeLifecycle(notificationCenter)
    }

    internal var sessionId: String {
        lock.lock(); defer { lock.unlock() }
        return id
    }

    internal var sessionNumber: Int {
        lock.lock(); defer { lock.unlock() }
        return number
    }

    internal func didEnterBackground() {
        let date = now()
        lock.lock(); defer { lock.unlock() }
        // The first notification wins: the app has been in background since then.
        guard backgroundStartDate == nil else { return }
        backgroundStartDate = date
        writeQueue.async { [defaults] in
            defaults.set(date, forKey: Self.lastBackgroundDateKey)
        }
    }

    internal func willEnterForeground() {
        let date = now()
        lock.lock(); defer { lock.unlock() }
        guard let start = backgroundStartDate else { return }
        backgroundStartDate = nil
        guard !isExternal, date.timeIntervalSince(start) > Self.backgroundTimeout else { return }
        startNewSession()
    }

    /// `logout()` boundary; ignored in external mode.
    internal func startNewSessionOnLogout() {
        lock.lock(); defer { lock.unlock() }
        guard !isExternal else { return }
        startNewSession()
    }

    /// Host-owned session id. Every request carries a lowercase UUID, so a value that is
    /// not a UUID is ignored.
    internal func setExternalSessionId(_ value: String) {
        guard let uuid = UUID(uuidString: value) else {
            apphudLog("Session id \"\(value)\" is not a UUID and was ignored.", forceDisplay: true)
            return
        }
        lock.lock(); defer { lock.unlock() }
        isExternal = true
        id = uuid.uuidString.lowercased()
    }

    /// An app launched straight into the background (background fetch, silent push) has
    /// been in background since launch.
    internal func markLaunchedInBackground() {
        lock.lock(); defer { lock.unlock() }
        guard backgroundStartDate == nil else { return }
        backgroundStartDate = launchDate
    }

    internal static var lifecycleNotificationNames: (background: Notification.Name, foreground: Notification.Name) {
        #if os(iOS) || os(tvOS) || os(visionOS)
        (UIApplication.didEnterBackgroundNotification, UIApplication.willEnterForegroundNotification)
        #elseif os(watchOS)
        (WKApplication.didEnterBackgroundNotification, WKApplication.willEnterForegroundNotification)
        #elseif os(macOS)
        // macOS has no background state: an inactive app counts as backgrounded.
        (NSApplication.didResignActiveNotification, NSApplication.didBecomeActiveNotification)
        #endif
    }

    // MARK: - Private

    /// Tests only: waits until queued writes reach UserDefaults.
    internal func waitForPendingWrites() {
        writeQueue.sync {}
    }

    // The caller holds the lock.
    private func startNewSession() {
        id = Self.makeId()
        number += 1
        persistNumber()
    }

    // The caller holds the lock, or is the initializer.
    private func persistNumber() {
        let number = self.number
        writeQueue.async { [defaults] in
            defaults.set(number, forKey: Self.numberKey)
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
        observers.append(center.addObserver(forName: names.foreground, object: nil, queue: nil) { [weak self] _ in
            self?.willEnterForeground()
        })
    }

    private func checkBackgroundLaunch() {
        #if os(iOS) || os(tvOS) || os(visionOS)
        Task { @MainActor [weak self] in
            if UIApplication.shared.applicationState == .background { self?.markLaunchedInBackground() }
        }
        #elseif os(watchOS)
        Task { @MainActor [weak self] in
            if WKApplication.shared().applicationState == .background { self?.markLaunchedInBackground() }
        }
        #endif
    }
}
