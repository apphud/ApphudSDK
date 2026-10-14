//
//  ApphudIdentity.swift
//  ApphudSDK
//
//  Three separate ids — installation, anonymous person, user — and reinstall detection.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

/// The ids of the current install and person.
internal struct ApphudIdentity: Equatable {
    /// One per install: new after a reinstall, kept across logout.
    var installationID: String
    /// The anonymous person: new after logout or a reinstall, kept by `updateUserID`.
    var anonymousID: String
    /// The app's own user id, set by identify. `nil` while anonymous.
    var userID: String?
    /// `true` reinstall, `false` first install, `nil` not known.
    var isReinstall: Bool?

    /// Whoever is current: the user once identified, the anonymous person before.
    var currentID: String { userID ?? anonymousID }

    /// Sent on every request in place of the old `device_id`.
    var requestParams: [String: String] {
        ["installation_id": installationID, "anonymous_id": anonymousID]
    }
}

/// Ids the host passed to `start`. An empty string means "not supplied", as before.
internal struct ApphudSuppliedIDs: Equatable {
    var userID: String?
    var anonymousID: String?
    var installationID: String?
    var isReinstall: Bool?

    init(userID: String? = nil, anonymousID: String? = nil, installationID: String? = nil, isReinstall: Bool? = nil) {
        self.userID = userID.apphudNonEmpty
        self.anonymousID = anonymousID.apphudNonEmpty
        self.installationID = installationID.apphudNonEmpty
        self.isReinstall = isReinstall
    }

    /// The app supplies every id and decides the reinstall flag itself. The SDK stores what it
    /// was given and never generates its own.
    var suppliesAllIDs: Bool { installationID != nil && anonymousID != nil }
}

internal enum ApphudLaunchKind: Equatable {
    /// `installation_id` already stored.
    case normal
    /// No `installation_id` yet, ids an old SDK version left: an in-place upgrade.
    case upgrade
    /// A first install or a reinstall.
    case newInstall
}

internal struct ApphudIdentityResolution: Equatable {
    var identity: ApphudIdentity
    var launch: ApphudLaunchKind
    /// The ids changed in this launch, so the backend has to see them.
    var changed: Bool
    /// The host passed another user while one was stored, without logout.
    var switchedUser: Bool = false
}

internal enum ApphudIdentifyOutcome: Equatable {
    case unchanged
    case identified
    /// A different user while identified, without logout.
    case switched
}

// MARK: - Installation record

internal struct ApphudInstallRecord: Codable, Equatable {
    var installationID: String
    var isReinstall: Bool?
    /// False while the reinstall check couldn't read the Keychain; it retries on later launches.
    var reinstallDecided: Bool
    /// The reinstall key is written and the old Keychain items are deleted.
    var keychainUpdated: Bool?
    /// A registration that carried `reinstall: true` succeeded: the backend has this install's reinstall.
    var reinstallReported: Bool?
    /// The `device_id` of the old SDK this install was updated from, sent as `legacy_device_id`
    /// until a registration succeeds: it adopts the old customer.
    var legacyDeviceID: String?
}

/// What the next registration reports besides the ids.
internal struct ApphudRegistrationReport: Equatable {
    /// `reinstall: true`, until a registration that carried it succeeds.
    var reinstall: Bool
    /// `legacy_device_id`, until a registration that carried it succeeds.
    var legacyDeviceID: String?
}

internal enum ApphudInstallRecordRead: Equatable {
    case found(ApphudInstallRecord)
    case missing
    /// The record exists but can't be read now (before the first unlock after a reboot).
    case unreadable
    /// The record exists but can't be used.
    case damaged
}

internal protocol ApphudInstallRecordStoring {
    func read() -> ApphudInstallRecordRead
    @discardableResult func write(_ record: ApphudInstallRecord) -> Bool
}

/// A backup-excluded file: new after a reinstall, never restored onto another device.
internal struct ApphudInstallRecordFile: ApphudInstallRecordStoring {
    let directory: URL
    var protectedDataAvailable: () -> Bool = ApphudInstallRecordFile.isProtectedDataAvailable

    var fileURL: URL { directory.appendingPathComponent("installation.json") }

    /// Per app: outside the sandbox on macOS, Application Support is shared by every app.
    static var standard: ApphudInstallRecordFile {
        let base = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first
            ?? FileManager.default.temporaryDirectory
        let app = Bundle.main.bundleIdentifier ?? "app"
        return ApphudInstallRecordFile(directory: base.appendingPathComponent("com.apphud", isDirectory: true)
            .appendingPathComponent(app, isDirectory: true))
    }

    func read() -> ApphudInstallRecordRead {
        guard FileManager.default.fileExists(atPath: fileURL.path) else { return .missing }
        let data: Data
        do {
            data = try Data(contentsOf: fileURL)
        } catch {
            // Data protection (before the first unlock) answers "no permission": wait, never
            // mint over the stored ids. macOS has no data protection.
            var waitForUnlock = !protectedDataAvailable()
            #if !os(macOS)
            waitForUnlock = waitForUnlock || Self.isPermissionError(error)
            #endif
            return waitForUnlock ? .unreadable : .damaged
        }
        guard let record = try? JSONDecoder().decode(ApphudInstallRecord.self, from: data) else {
            apphudLog("Installation record is damaged, a new one will be created", forceDisplay: true)
            return .damaged
        }
        return .found(record)
    }

    @discardableResult
    func write(_ record: ApphudInstallRecord) -> Bool {
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try Self.excludeFromBackup(directory)
            try JSONEncoder().encode(record).write(to: fileURL, options: .atomic)
            // An atomic write replaces the file and drops the flag, so it is set again.
            try Self.excludeFromBackup(fileURL)
            return true
        } catch {
            apphudLog("Failed to save the installation record: \(error)", forceDisplay: true)
            return false
        }
    }

    static func isPermissionError(_ error: Error) -> Bool {
        let nsError = error as NSError
        if nsError.domain == NSCocoaErrorDomain, nsError.code == NSFileReadNoPermissionError { return true }
        let posix = (nsError.userInfo[NSUnderlyingErrorKey] as? NSError) ?? nsError
        return posix.domain == NSPOSIXErrorDomain && (posix.code == Int(EPERM) || posix.code == Int(EACCES))
    }

    private static func excludeFromBackup(_ url: URL) throws {
        var url = url
        var values = URLResourceValues()
        values.isExcludedFromBackup = true
        try url.setResourceValues(values)
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
}

#if os(tvOS)
/// tvOS keeps nothing on disk across launches but UserDefaults: other files can be purged.
internal struct ApphudInstallRecordDefaults: ApphudInstallRecordStoring {
    let defaults: UserDefaults
    private static let key = "com.apphud.installation"

    func read() -> ApphudInstallRecordRead {
        guard let data = defaults.data(forKey: Self.key) else { return .missing }
        guard let record = try? JSONDecoder().decode(ApphudInstallRecord.self, from: data) else { return .damaged }
        return .found(record)
    }

    @discardableResult
    func write(_ record: ApphudInstallRecord) -> Bool {
        guard let data = try? JSONEncoder().encode(record) else { return false }
        defaults.set(data, forKey: Self.key)
        return true
    }
}
#endif

// MARK: - Store

/// Resolves, persists and changes the ids. Keychain, UserDefaults and the installation record
/// are injected, so tests drive every launch case.
internal final class ApphudIdentityStore {

    static let anonymousIDKey = "com.apphud.anonymous_id"
    /// Holds only a user id the app set. Old versions kept the SDK-generated one here too.
    static let userIDKey = "com.apphud.user_id"
    /// Old versions only. Read once on upgrade, then removed.
    static let legacyDeviceIDKey = "com.apphud.device_id"
    /// Set while the backend hasn't seen the current ids; cleared by a successful registration.
    static let syncPendingKey = "com.apphud.identity_sync_pending"

    private let defaults: UserDefaults
    private let keychain: ApphudKeychainStoring
    private let installRecords: ApphudInstallRecordStoring
    private let makeID: () -> String
    private let lock = NSLock()
    /// The old device_id of an upgrade whose record couldn't be saved: still sent this launch.
    private var unsavedLegacyDeviceID: String?

    init(defaults: UserDefaults = .standard,
         keychain: ApphudKeychainStoring = ApphudSystemKeychain(),
         installRecords: ApphudInstallRecordStoring? = nil,
         makeID: @escaping () -> String = { UUID().uuidString }) {
        self.defaults = defaults
        self.keychain = keychain
        #if os(tvOS)
        self.installRecords = installRecords ?? ApphudInstallRecordDefaults(defaults: defaults)
        #else
        self.installRecords = installRecords ?? ApphudInstallRecordFile.standard
        #endif
        self.makeID = makeID
    }

    /// The installation id is already stored and readable: the launch needs no Keychain read.
    var hasInstallRecord: Bool {
        if case .found = installRecords.read() { return true }
        return false
    }

    /// The backend hasn't seen the current ids yet, so registration must not be skipped.
    var isSyncPending: Bool { defaults.bool(forKey: Self.syncPendingKey) }

    func markSynced() {
        defaults.removeObject(forKey: Self.syncPendingKey)
    }

    /// Resolves the ids at `start`. `nil` when the stored ones can't be read yet.
    func resolve(_ supplied: ApphudSuppliedIDs) -> ApphudIdentityResolution? {
        let stored: ApphudInstallRecord?
        var damaged = false
        switch installRecords.read() {
        case .unreadable: return nil
        case .missing: stored = nil
        case .damaged: stored = nil; damaged = true
        case .found(let record): stored = record
        }
        let storedAnonymousID = defaults.string(forKey: Self.anonymousIDKey).apphudNonEmpty
        let storedUserID = defaults.string(forKey: Self.userIDKey).apphudNonEmpty

        if supplied.suppliesAllIDs {
            return resolveSupplied(supplied, stored: stored, storedAnonymousID: storedAnonymousID, storedUserID: storedUserID)
        }

        var anonymousID = storedAnonymousID
        var userID = storedUserID
        var record: ApphudInstallRecord
        let launch: ApphudLaunchKind
        let legacyDeviceID = defaults.string(forKey: Self.legacyDeviceIDKey).apphudNonEmpty
        // Old versions kept user_id in UserDefaults but never anonymous_id; with
        // `startManually(deviceID:)` they never stored device_id there.
        let oldVersionLeftIDs = legacyDeviceID != nil || (storedUserID != nil && storedAnonymousID == nil)

        if let stored {
            launch = .normal
            record = stored
            if !stored.reinstallDecided, let isReinstall = checkReinstall() {
                // The Keychain was locked when this install started; the first successful read decides.
                record.isReinstall = isReinstall
                record.reinstallDecided = true
            }
        } else if oldVersionLeftIDs {
            // In-place upgrade: the old device_id stays as installation_id and goes as
            // legacy_device_id, which has the backend adopt the old customer. Never taken from the Keychain.
            launch = .upgrade
            record = ApphudInstallRecord(installationID: legacyDeviceID ?? makeID(), isReinstall: nil, reinstallDecided: true,
                                         legacyDeviceID: legacyDeviceID)
            if let legacyDeviceID, userID == legacyDeviceID {
                // A user_id equal to the device_id was generated by the SDK: it is the anonymous id.
                anonymousID = legacyDeviceID
                userID = nil
            }
        } else if damaged {
            // The record was there: our own reinstall key may be too, so it gives no verdict.
            launch = .newInstall
            record = ApphudInstallRecord(installationID: makeID(), isReinstall: nil, reinstallDecided: true)
        } else {
            launch = .newInstall
            let isReinstall = checkReinstall()
            record = ApphudInstallRecord(installationID: makeID(), isReinstall: isReinstall, reinstallDecided: isReinstall != nil)
        }

        // The stored user after the upgrade rewrite: an SDK-generated id was never a user.
        let userBeforeSupplied = userID

        // Ids the host supplied are kept as given: never minted over, never rotated.
        if let installationID = supplied.installationID {
            record.installationID = installationID
        }
        if let suppliedAnonymousID = supplied.anonymousID {
            anonymousID = suppliedAnonymousID
        }
        let resolvedAnonymousID = anonymousID ?? makeID()
        // The anonymous id is never a user: a supplied one is ignored (the stored user stays), a
        // stored one is dropped.
        if let suppliedUserID = supplied.userID, suppliedUserID != resolvedAnonymousID {
            userID = suppliedUserID
        }
        if userID == resolvedAnonymousID {
            userID = nil
        }

        let switchedUser = Self.isSwitch(from: userBeforeSupplied, to: userID)
        if switchedUser {
            // The old customer belongs to the user before.
            record.legacyDeviceID = nil
        }

        let changed = record.installationID != stored?.installationID || record.isReinstall != stored?.isReinstall
            || resolvedAnonymousID != storedAnonymousID || userID != storedUserID
        if changed {
            markSyncPending()
        }
        // An upgrade adopts the ids before the old device_id is deleted: a crash in between must
        // not leave an SDK-generated user_id behind as a real user. Other launches save them after
        // the record, so a crash in between never makes an old install look like a new one.
        if legacyDeviceID != nil {
            persist(anonymousID: resolvedAnonymousID, userID: userID)
        }

        // The record is saved before the Keychain changes: a crash in between must not leave our
        // own key behind for a launch that has no record.
        if record == stored || installRecords.write(record) {
            setUnsavedLegacyDeviceID(nil)
            if legacyDeviceID != nil {
                defaults.removeObject(forKey: Self.legacyDeviceIDKey)
            }
            if record.reinstallDecided, record.keychainUpdated != true, updateKeychain() {
                record.keychainUpdated = true
                installRecords.write(record)
            }
        } else {
            // The next launch upgrades again; this one still has the old customer adopted.
            setUnsavedLegacyDeviceID(record.legacyDeviceID)
        }
        persist(anonymousID: resolvedAnonymousID, userID: userID)

        let identity = ApphudIdentity(installationID: record.installationID, anonymousID: resolvedAnonymousID,
                                      userID: userID, isReinstall: record.isReinstall)
        return ApphudIdentityResolution(identity: identity, launch: launch, changed: changed,
                                        switchedUser: switchedUser)
    }

    /// What the next registration reports: the reinstall and the old device_id, each until a
    /// registration that carried it succeeds.
    func registrationReport(for identity: ApphudIdentity) -> ApphudRegistrationReport {
        guard case .found(let record) = installRecords.read() else {
            return ApphudRegistrationReport(reinstall: identity.isReinstall == true, legacyDeviceID: unsavedLegacyDeviceIDValue())
        }
        return ApphudRegistrationReport(reinstall: identity.isReinstall == true && record.reinstallReported != true,
                                        legacyDeviceID: record.legacyDeviceID)
    }

    /// A registration succeeded: what it reported is not sent again.
    func markRegistered(reinstallSent: Bool, legacyDeviceIDSent: Bool) {
        if legacyDeviceIDSent { setUnsavedLegacyDeviceID(nil) }
        guard reinstallSent || legacyDeviceIDSent, case .found(var record) = installRecords.read() else { return }
        if reinstallSent { record.reinstallReported = true }
        if legacyDeviceIDSent { record.legacyDeviceID = nil }
        installRecords.write(record)
    }

    /// `updateUserID`: identify while anonymous, a switch while identified, a no-op for the same id.
    func identify(_ userID: String, _ identity: inout ApphudIdentity) -> ApphudIdentifyOutcome {
        guard identity.userID != userID, userID != identity.anonymousID else { return .unchanged }
        let outcome: ApphudIdentifyOutcome = identity.userID == nil ? .identified : .switched
        identity.userID = userID
        persist(anonymousID: identity.anonymousID, userID: userID)
        markSyncPending()
        if outcome == .switched {
            forgetLegacyDeviceID()
        }
        return outcome
    }

    /// Logout: a new anonymous id (the supplied one, or a fresh one), no user; the installation stays.
    func logout(anonymousID: String?, _ identity: inout ApphudIdentity) {
        identity.anonymousID = anonymousID.apphudNonEmpty ?? makeID()
        identity.userID = nil
        persist(anonymousID: identity.anonymousID, userID: nil)
        markSyncPending()
        forgetLegacyDeviceID()
    }

    // MARK: - Private

    /// Every id supplied by the app: the app owns the ids and the reinstall flag. No Keychain item
    /// is read or written, and no old key is touched.
    private func resolveSupplied(_ supplied: ApphudSuppliedIDs, stored: ApphudInstallRecord?,
                                 storedAnonymousID: String?, storedUserID: String?) -> ApphudIdentityResolution {
        let installationID = supplied.installationID!
        let anonymousID = supplied.anonymousID!
        // The host passes a user id when it has one: none means no user. The anonymous id is never one.
        let userID = supplied.userID == anonymousID ? nil : supplied.userID

        var record = stored ?? ApphudInstallRecord(installationID: installationID, isReinstall: nil, reinstallDecided: true)
        record.installationID = installationID
        let switchedUser = Self.isSwitch(from: storedUserID, to: userID)
        if switchedUser {
            // The old customer belongs to the user before.
            record.legacyDeviceID = nil
        }
        if record != stored {
            installRecords.write(record)
        }
        persist(anonymousID: anonymousID, userID: userID)

        let identity = ApphudIdentity(installationID: installationID, anonymousID: anonymousID,
                                      userID: userID, isReinstall: supplied.isReinstall)
        let changed = installationID != stored?.installationID || anonymousID != storedAnonymousID || userID != storedUserID
        if changed {
            markSyncPending()
        }
        return ApphudIdentityResolution(identity: identity, launch: stored == nil ? .newInstall : .normal,
                                        changed: changed, switchedUser: switchedUser)
    }

    /// The person changed before a registration adopted the old customer: it belongs to the one before.
    private func forgetLegacyDeviceID() {
        setUnsavedLegacyDeviceID(nil)
        guard case .found(var record) = installRecords.read(), record.legacyDeviceID != nil else { return }
        record.legacyDeviceID = nil
        installRecords.write(record)
    }

    private func unsavedLegacyDeviceIDValue() -> String? {
        lock.lock(); defer { lock.unlock() }
        return unsavedLegacyDeviceID
    }

    private func setUnsavedLegacyDeviceID(_ value: String?) {
        lock.lock(); defer { lock.unlock() }
        unsavedLegacyDeviceID = value
    }

    private static func isSwitch(from storedUserID: String?, to userID: String?) -> Bool {
        guard let storedUserID, let userID else { return false }
        return storedUserID != userID
    }

    /// `nil` when the Keychain can't be read: unknown is never taken for "first install".
    private func checkReinstall() -> Bool? {
        let key = keychain.read(.reinstall)
        let legacyKey = keychain.read(.legacyDeviceID)
        guard key != .unavailable, legacyKey != .unavailable else { return nil }
        // An old key counts too, even "": the app was deleted on an old SDK version.
        return key.isFound || legacyKey.isFound
    }

    /// Writes the reinstall key after a successful read, deletes the old items. False when the
    /// Keychain can't be read: the next launch tries again.
    private func updateKeychain() -> Bool {
        switch keychain.read(.reinstall) {
        case .unavailable:
            return false
        case .notFound:
            guard keychain.write(.reinstall, value: "1") else { return false }
        case .found:
            break
        }
        keychain.delete(.legacyDeviceID)
        keychain.delete(.legacyUserID)
        return true
    }

    private func persist(anonymousID: String, userID: String?) {
        defaults.set(anonymousID, forKey: Self.anonymousIDKey)
        if let userID {
            defaults.set(userID, forKey: Self.userIDKey)
        } else {
            defaults.removeObject(forKey: Self.userIDKey)
        }
    }

    private func markSyncPending() {
        defaults.set(true, forKey: Self.syncPendingKey)
    }
}

extension Optional where Wrapped == String {
    /// `nil` for nil or "".
    var apphudNonEmpty: String? {
        guard let value = self, !value.isEmpty else { return nil }
        return value
    }
}

extension CharacterSet {
    /// A query value: `&`, `=`, `+`, `?` and `#` are escaped too.
    static let apphudQueryValueAllowed = CharacterSet.urlQueryAllowed.subtracting(CharacterSet(charactersIn: "&=+?#"))
}
