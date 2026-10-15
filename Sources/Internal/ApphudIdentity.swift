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

    /// The same ids. The reinstall answer the app gives may change while a request is out.
    func hasSameIDs(as other: ApphudIdentity) -> Bool {
        installationID == other.installationID && anonymousID == other.anonymousID && userID == other.userID
    }

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
    /// `startManually(deviceID:)`: identity version 1's device id. Version 2 takes it as the installation id.
    var deviceID: String?

    init(userID: String? = nil, anonymousID: String? = nil, installationID: String? = nil, isReinstall: Bool? = nil,
         deviceID: String? = nil) {
        self.userID = userID.apphudNonEmpty
        self.anonymousID = anonymousID.apphudNonEmpty
        self.installationID = installationID.apphudNonEmpty
        self.isReinstall = isReinstall
        self.deviceID = deviceID.apphudNonEmpty
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
    /// The reinstall key is written.
    var keychainUpdated: Bool?
    /// A registration that carried `reinstall: true` succeeded: the backend has this install's reinstall.
    var reinstallReported: Bool?
    /// The `device_id` of the old SDK this install was updated from, sent as `legacy_device_id`
    /// until a registration succeeds, not after a logout or a user switch: it adopts the old customer.
    var legacyDeviceID: String?
    /// The app's own reinstall answer when it supplies the ids, kept until it changes: an answer that
    /// came after `start` still reaches a later launch's registration.
    var hostIsReinstall: Bool?
}

/// What the next registration reports besides the ids.
internal struct ApphudRegistrationReport: Equatable {
    /// `reinstall: true`, until a registration that carried it succeeds.
    var reinstall: Bool
    /// `legacy_device_id`, until a registration that carried it succeeds; not after a logout or a user switch.
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
    /// The device_id of identity version 1 (and of old versions). Kept while version 2 runs, so
    /// version 1 can come back to the same customer.
    static let legacyDeviceIDKey = "com.apphud.device_id"
    /// The old version's generated device_id, kept for good after an upgrade: apps that saved it as
    /// their user id pass it back, and it is never a user.
    static let oldDeviceIDKey = "com.apphud.old_device_id"
    /// Set while the backend hasn't seen the current ids; cleared by a successful registration.
    static let syncPendingKey = "com.apphud.identity_sync_pending"
    /// The identity version that ran last here, "v1" or "v2". Absent before it existed.
    static let identityVersionKey = "com.apphud.identity_version"
    /// Set by a logout on version 2: the device id of version 1 belonged to the person logged out.
    static let version1IDsResetKey = "com.apphud.version1_ids_reset"
    /// Set by a logout on version 1: the next start on version 2 takes its new person, and the old ids
    /// of version 1 belong to the person logged out.
    static let version1LoggedOutKey = "com.apphud.version1_logged_out"
    /// Set when version 1 takes the ids of version 2 over, until a registration of version 1 succeeds:
    /// the backend has to see its device id.
    static let version1RegistrationPendingKey = "com.apphud.version1_registration_pending"
    private static let version1 = "v1"
    private static let version2 = "v2"

    private let defaults: UserDefaults
    private let keychain: ApphudKeychainStoring
    private let installRecords: ApphudInstallRecordStoring
    private let makeID: () -> String
    private let lock = NSLock()
    /// The old device_id of an upgrade whose record couldn't be saved: still sent this launch.
    private var unsavedLegacyDeviceID: String?
    /// A logout or a user switch dropped the old device_id in this process.
    private var legacyDeviceIDForgottenInProcess = false
    /// The stored version 1 registration flag, read once: requests check it every time they go.
    private var version1RegistrationPendingValue: Bool?

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
        let lastVersion = defaults.string(forKey: Self.identityVersionKey)
        var version1LoggedOut = false
        // The old device_id of an install reinstalled on an old SDK version, which kept it in the Keychain only.
        var keychainOnlyDeviceID: String?
        // Old versions kept user_id in UserDefaults but never anonymous_id; with
        // `startManually(deviceID:)` they never stored device_id there. The ids version 2 keeps
        // for version 1 are no update: they come with its own ids, from this phone or from a backup.
        let oldVersionLeftIDs = lastVersion != Self.version2
            && (legacyDeviceID != nil || (storedUserID != nil && storedAnonymousID == nil))

        if let stored, lastVersion != Self.version1 {
            launch = .normal
            record = stored
            if !stored.reinstallDecided, let isReinstall = checkReinstall() {
                // The Keychain was locked when this install started; the first successful read decides.
                record.isReinstall = isReinstall
                record.reinstallDecided = true
            }
        } else if let stored {
            // Version 1 ran since: its device_id adopts its customer again, as on the first update,
            // and its ids are the current ones. The installation stays.
            launch = .upgrade
            record = stored
            record.legacyDeviceID = legacyDeviceID
            version1LoggedOut = defaults.bool(forKey: Self.version1LoggedOutKey)
            if let legacyDeviceID, userID == legacyDeviceID {
                anonymousID = legacyDeviceID
                userID = nil
            } else if let current = userID, current == storedAnonymousID {
                // Version 1 sent version 2's anonymous id as its user id: still the anonymous person.
                userID = nil
            } else if version1LoggedOut {
                // Its person, not the anonymous id from before the logout.
                anonymousID = nil
            }
        } else if oldVersionLeftIDs {
            // In-place upgrade: the old device_id stays as installation_id and goes as
            // legacy_device_id, which has the backend adopt the old customer. Never taken from the Keychain.
            launch = .upgrade
            record = ApphudInstallRecord(installationID: legacyDeviceID ?? makeID(), isReinstall: nil, reinstallDecided: true,
                                         legacyDeviceID: legacyDeviceID)
            // Version 1 ran last on these ids, from a backup too, and logged out.
            version1LoggedOut = lastVersion == Self.version1 && defaults.bool(forKey: Self.version1LoggedOutKey)
            if let legacyDeviceID, userID == legacyDeviceID {
                // A user_id equal to the device_id was generated by the SDK: it is the anonymous id.
                anonymousID = legacyDeviceID
                userID = nil
            } else if lastVersion == Self.version1, let current = userID, current == storedAnonymousID {
                // Version 1 sent version 2's anonymous id as its user id: still the anonymous person.
                userID = nil
            } else if version1LoggedOut {
                // Its person, not the anonymous id from before the logout.
                anonymousID = nil
            } else if legacyDeviceID == nil, let storedUser = userID,
                      case .found(let oldDeviceID) = keychain.read(.legacyDeviceID), oldDeviceID == storedUser {
                // Reinstalled on an old SDK version, which restored its device_id from the Keychain and never
                // saved it back: a user_id equal to it was generated by the SDK too. The item is only compared,
                // never sent: the backend finds the old customer by this anonymous id.
                keychainOnlyDeviceID = oldDeviceID
                anonymousID = oldDeviceID
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

        if launch == .newInstall, lastVersion == Self.version1, defaults.bool(forKey: Self.version1LoggedOutKey) {
            // Version 1 ran last on these ids and logged out, and this install has no record (a backup,
            // or a damaged record): the anonymous id from before the logout doesn't come back. A user
            // version 1 started with since stays.
            version1LoggedOut = true
            anonymousID = nil
        }

        if anonymousID == nil, !version1LoggedOut, let current = userID, current == oldDeviceID {
            // An update stopped after its record and before its ids were saved: the old SDK's generated
            // device_id, still in the user's place, is the anonymous id.
            anonymousID = current
            userID = nil
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
        if let oldVersionDeviceID = legacyDeviceID ?? keychainOnlyDeviceID, oldDeviceID == nil {
            defaults.set(oldVersionDeviceID, forKey: Self.oldDeviceIDKey)
        }
        // Generated ids are never a user: a supplied one is ignored (the stored user stays), a stored
        // one is dropped.
        let generatedIDs = Set([resolvedAnonymousID, oldDeviceID].compactMap { $0 })
        if let suppliedUserID = supplied.userID, !generatedIDs.contains(suppliedUserID) {
            userID = suppliedUserID
        }
        if let current = userID, generatedIDs.contains(current) {
            userID = nil
        }

        let switchedUser = Self.isSwitch(from: userBeforeSupplied, to: userID)
        if switchedUser {
            // Not after a user switch: the old customer belongs to the user before.
            record.legacyDeviceID = nil
            markLegacyDeviceIDForgottenInProcess()
        }

        let changed = record.installationID != stored?.installationID || record.isReinstall != stored?.isReinstall
            || resolvedAnonymousID != storedAnonymousID || userID != storedUserID
            || record.legacyDeviceID != stored?.legacyDeviceID
        if changed {
            markSyncPending()
        }
        // An upgrade saves the ids it adopted before the record: a crash in between must
        // not leave an SDK-generated user_id behind as a real user. Other launches save them after
        // the record, so a crash in between never makes an old install look like a new one.
        // Not after a user switch: the record without the old customer goes first, so a crash in
        // between leaves the user before, and the next launch drops it again.
        if legacyDeviceID != nil, !switchedUser {
            persist(anonymousID: resolvedAnonymousID, userID: userID)
        }

        // The record is saved before the Keychain changes: a crash in between must not leave our
        // own key behind for a launch that has no record.
        let saved = record == stored || installRecords.write(record)
        if saved {
            setUnsavedLegacyDeviceID(nil)
            if record.reinstallDecided, record.keychainUpdated != true, updateKeychain() {
                record.keychainUpdated = true
                installRecords.write(record)
            }
        } else {
            // The next launch upgrades again; this one still has the old customer adopted.
            setUnsavedLegacyDeviceID(record.legacyDeviceID)
        }
        persist(anonymousID: resolvedAnonymousID, userID: userID)
        // The person after version 1's logout is saved: a later launch keeps it.
        if version1LoggedOut {
            defaults.removeObject(forKey: Self.version1LoggedOutKey)
            // No device id of its own since the logout: the next version 1 makes a new one.
            if legacyDeviceID == nil {
                defaults.set(true, forKey: Self.version1IDsResetKey)
            }
        }
        // Last: a launch that didn't finish runs the switch from version 1 again.
        if saved {
            defaults.set(Self.version2, forKey: Self.identityVersionKey)
        }

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
                                        legacyDeviceID: legacyDeviceIDForgotten() ? nil : record.legacyDeviceID)
    }

    /// The app's reinstall answer that arrived after `start`, kept for later launches: a reinstall not
    /// reported yet keeps the next registration from being skipped, on a later launch too.
    func keepReinstallAnswer(_ isReinstall: Bool) {
        var reported = false
        if case .found(var record) = installRecords.read() {
            reported = record.reinstallReported == true
            if record.hostIsReinstall != isReinstall {
                record.hostIsReinstall = isReinstall
                installRecords.write(record)
            }
        }
        if isReinstall && !reported {
            markSyncPending()
        }
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
        guard identity.userID != userID, userID != identity.anonymousID, userID != oldDeviceID else { return .unchanged }
        let outcome: ApphudIdentifyOutcome = identity.userID == nil ? .identified : .switched
        if outcome == .switched {
            // Before the new user is saved: a crash in between must not leave the old customer to them.
            forgetLegacyDeviceID()
        }
        identity.userID = userID
        persist(anonymousID: identity.anonymousID, userID: userID)
        markSyncPending()
        return outcome
    }

    /// Logout: a new anonymous id (the supplied one, or a fresh one), no user; the installation stays.
    func logout(anonymousID: String?, _ identity: inout ApphudIdentity) {
        // The ids of version 1 belong to the person logged out: version 1 starts a new device id, as
        // its own logout does. Reset before the new person is saved: a crash in between must not leave
        // the old device id to the new person.
        defaults.set(true, forKey: Self.version1IDsResetKey)
        defaults.removeObject(forKey: Self.legacyDeviceIDKey)
        // Not after a logout: the old customer is the logged-out person's.
        forgetLegacyDeviceID()
        // Its Keychain items are blanked, as its own logout does: version 1 after a reinstall starts a
        // new device id.
        for key in [ApphudKeychainKey.legacyDeviceID, .legacyUserID] where keychain.read(key).isFound {
            keychain.write(key, value: "")
        }
        identity.anonymousID = anonymousID.apphudNonEmpty ?? makeID()
        identity.userID = nil
        persist(anonymousID: identity.anonymousID, userID: nil)
        markSyncPending()
    }

    /// Identity version 1 after version 2 ran here: the ids it sends, so the backend finds the same
    /// customer by the user id. The device id is the old one, or the installation id when the install
    /// started on version 2. `nil` when version 2 never ran here.
    func idsForVersion1() -> (deviceID: String?, userID: String)? {
        let lastVersion = defaults.string(forKey: Self.identityVersionKey)
        let anonymousID = defaults.string(forKey: Self.anonymousIDKey).apphudNonEmpty
        // After a logout on version 2, whatever the marker says, version 1 starts with a new device id,
        // never one the Keychain may still hold.
        if defaults.bool(forKey: Self.version1IDsResetKey), let anonymousID {
            return (makeID(), defaults.string(forKey: Self.userIDKey).apphudNonEmpty ?? anonymousID)
        }
        // Builds before the version marker ran version 2 only.
        guard lastVersion == Self.version2 || (lastVersion == nil && anonymousID != nil) else { return nil }
        guard let userID = defaults.string(forKey: Self.userIDKey).apphudNonEmpty ?? anonymousID else { return nil }
        var deviceID = defaults.string(forKey: Self.legacyDeviceIDKey).apphudNonEmpty ?? oldDeviceID
        if deviceID == nil, case .found(let record) = installRecords.read() {
            deviceID = record.installationID
        }
        return (deviceID, userID)
    }

    /// Identity version 1 ran: the next start on version 2 takes its ids over. `tookOverVersion2`: this
    /// start took the ids of version 2 over, and a registration has to show the backend its device id.
    func markVersion1(tookOverVersion2: Bool = false) {
        if tookOverVersion2 {
            defaults.removeObject(forKey: Self.version1IDsResetKey)
            defaults.removeObject(forKey: Self.version1LoggedOutKey)
            setVersion1RegistrationPending(true)
        }
        defaults.set(Self.version1, forKey: Self.identityVersionKey)
    }

    /// A logout on version 1.
    func markVersion1LoggedOut() {
        defaults.set(true, forKey: Self.version1LoggedOutKey)
    }

    /// Version 1 took the ids of version 2 over and no registration of it has succeeded yet.
    var isVersion1RegistrationPending: Bool {
        lock.lock(); defer { lock.unlock() }
        if let pending = version1RegistrationPendingValue { return pending }
        let pending = defaults.bool(forKey: Self.version1RegistrationPendingKey)
        version1RegistrationPendingValue = pending
        return pending
    }

    func markVersion1Registered() {
        setVersion1RegistrationPending(false)
    }

    private func setVersion1RegistrationPending(_ pending: Bool) {
        lock.lock()
        let stored = version1RegistrationPendingValue ?? defaults.bool(forKey: Self.version1RegistrationPendingKey)
        version1RegistrationPendingValue = pending
        lock.unlock()
        // Every registration of version 1 clears it: write only a change, as SDK 4.6 wrote nothing there.
        // UserDefaults posts its change notification inside the write, so never under `lock`.
        guard stored != pending else { return }
        if pending {
            defaults.set(true, forKey: Self.version1RegistrationPendingKey)
        } else {
            defaults.removeObject(forKey: Self.version1RegistrationPendingKey)
        }
    }

    /// The identity version that ran last here; `nil` before either ran.
    var lastIdentityVersion: ApphudIdentityVersion? {
        switch defaults.string(forKey: Self.identityVersionKey) {
        case Self.version1: return .v1
        case Self.version2: return .v2
        // Builds before the version marker, or a first launch whose record wasn't saved, ran version 2.
        default: return defaults.string(forKey: Self.anonymousIDKey).apphudNonEmpty == nil ? nil : .v2
        }
    }

    // MARK: - Private

    /// Every id supplied by the app: the app owns the ids and the reinstall flag. No Keychain item
    /// is read or written, and no old key is touched.
    private func resolveSupplied(_ supplied: ApphudSuppliedIDs, stored: ApphudInstallRecord?,
                                 storedAnonymousID: String?, storedUserID: String?) -> ApphudIdentityResolution {
        let installationID = supplied.installationID!
        let anonymousID = supplied.anonymousID!
        // The host passes a user id when it has one: none means no user. Generated ids are never one.
        let userID = supplied.userID == anonymousID || supplied.userID == oldDeviceID ? nil : supplied.userID

        var record = stored ?? ApphudInstallRecord(installationID: installationID, isReinstall: nil, reinstallDecided: true)
        record.installationID = installationID
        // The answer passed now, else the one the app gave after an earlier start for this installation.
        if stored?.installationID != installationID {
            record.hostIsReinstall = nil
        }
        if let answer = supplied.isReinstall {
            record.hostIsReinstall = answer
        }
        if Self.isSwitch(from: storedUserID, to: userID) || (storedAnonymousID != nil && anonymousID != storedAnonymousID) {
            // Not after a user switch or a logout (the host's new anonymous id): the old customer belongs
            // to the person before.
            record.legacyDeviceID = nil
            markLegacyDeviceIDForgottenInProcess()
        }
        if record != stored {
            installRecords.write(record)
        }
        persist(anonymousID: anonymousID, userID: userID)
        defaults.set(Self.version2, forKey: Self.identityVersionKey)

        let identity = ApphudIdentity(installationID: installationID, anonymousID: anonymousID,
                                      userID: userID, isReinstall: record.hostIsReinstall)
        let changed = installationID != stored?.installationID || anonymousID != storedAnonymousID || userID != storedUserID
        // A reinstall the app reports goes until a registration carries it: none is skipped till then.
        if changed || (record.hostIsReinstall == true && record.reinstallReported != true) {
            markSyncPending()
        }
        return ApphudIdentityResolution(identity: identity, launch: stored == nil ? .newInstall : .normal,
                                        changed: changed, switchedUser: Self.isSwitch(from: storedUserID, to: userID))
    }

    /// `legacy_device_id` goes until the first successful registration, not after a logout or a user
    /// switch: the old customer belongs to the person before.
    private func forgetLegacyDeviceID() {
        markLegacyDeviceIDForgottenInProcess()
        guard case .found(var record) = installRecords.read(), record.legacyDeviceID != nil else { return }
        record.legacyDeviceID = nil
        installRecords.write(record)
    }

    /// Forgotten in this process even when the record can't be saved.
    private func markLegacyDeviceIDForgottenInProcess() {
        lock.lock(); defer { lock.unlock() }
        unsavedLegacyDeviceID = nil
        legacyDeviceIDForgottenInProcess = true
    }

    private func legacyDeviceIDForgotten() -> Bool {
        lock.lock(); defer { lock.unlock() }
        return legacyDeviceIDForgottenInProcess
    }

    private func unsavedLegacyDeviceIDValue() -> String? {
        lock.lock(); defer { lock.unlock() }
        return unsavedLegacyDeviceID
    }

    private func setUnsavedLegacyDeviceID(_ value: String?) {
        lock.lock(); defer { lock.unlock() }
        unsavedLegacyDeviceID = value
    }

    private var oldDeviceID: String? { defaults.string(forKey: Self.oldDeviceIDKey).apphudNonEmpty }

    private static func isSwitch(from storedUserID: String?, to userID: String?) -> Bool {
        guard let storedUserID, let userID else { return false }
        return storedUserID != userID
    }

    /// `nil` when the Keychain can't be read: unknown is never taken for "first install". Only the
    /// reinstall key counts: the old `ApphudDeviceID` moves to a new phone with a backup, so a
    /// reinstall straight from an old SDK version reads as a first install.
    private func checkReinstall() -> Bool? {
        let key = keychain.read(.reinstall)
        guard key != .unavailable else { return nil }
        return key.isFound
    }

    /// Writes the reinstall key after a successful read. The items of version 1 stay, so it can come
    /// back to the same ids. False when the Keychain can't be read: the next launch tries again.
    private func updateKeychain() -> Bool {
        switch keychain.read(.reinstall) {
        case .unavailable:
            return false
        case .notFound:
            guard keychain.write(.reinstall, value: "1") else { return false }
        case .found:
            break
        }
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
