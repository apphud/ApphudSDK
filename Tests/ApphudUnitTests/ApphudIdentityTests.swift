//
//  ApphudIdentityTests.swift
//  ApphudUnitTests
//
//  installation_id, anonymous_id and user_id, and reinstall detection.
//  One test per row of the identity model and of the launch flow, plus the reinstall cases.
//

import XCTest
#if os(iOS)
import UIKit
#endif
@testable import ApphudSDK

/// The Keychain: survives deleting the app on the same phone, never travels to another one.
private final class FakeKeychain: ApphudKeychainStoring {
    var items: [ApphudKeychainKey: String] = [:]
    var locked = false
    /// Reads fail while writes still go through.
    var readsFail = false
    /// Called before every access, e.g. to see what was on disk at that moment.
    var onAccess: (() -> Void)?
    private(set) var accessCount = 0

    func read(_ key: ApphudKeychainKey) -> ApphudKeychainRead {
        onAccess?()
        accessCount += 1
        if locked || readsFail { return .unavailable }
        return items[key].map { .found($0) } ?? .notFound
    }

    func write(_ key: ApphudKeychainKey, value: String) -> Bool {
        onAccess?()
        accessCount += 1
        if locked { return false }
        items[key] = value
        return true
    }

    func delete(_ key: ApphudKeychainKey) {
        onAccess?()
        accessCount += 1
        if !locked { items[key] = nil }
    }
}

/// The backup-excluded installation file.
private final class FakeInstallRecords: ApphudInstallRecordStoring {
    var record: ApphudInstallRecord?
    var unreadable = false
    var damaged = false
    var failWrites = false
    /// Called before every write, e.g. to see what was on disk at that moment.
    var onWrite: (() -> Void)?

    func read() -> ApphudInstallRecordRead {
        if unreadable { return .unreadable }
        if damaged { return .damaged }
        return record.map { .found($0) } ?? .missing
    }

    func write(_ record: ApphudInstallRecord) -> Bool {
        onWrite?()
        if failWrites { return false }
        self.record = record
        return true
    }
}

final class ApphudIdentityTests: XCTestCase {

    // One phone: its Keychain. One app install on it: UserDefaults and the installation file.
    private var keychain: FakeKeychain!
    private var installRecords: FakeInstallRecords!
    private var defaults: UserDefaults!
    private var suiteNames: [String] = []
    private var idCounter = 0

    private var savedIdentityVersion = ApphudIdentityVersion.v1

    override func setUp() {
        super.setUp()
        keychain = FakeKeychain()
        installApp()
        savedIdentityVersion = ApphudInternal.shared.identityVersion
        ApphudInternal.shared.identityVersion = .v2
    }

    override func tearDown() {
        ApphudInternal.shared.identityVersion = savedIdentityVersion
        suiteNames.forEach { UserDefaults().removePersistentDomain(forName: $0) }
        super.tearDown()
    }

    // MARK: - Device helpers

    /// A fresh app container: empty UserDefaults, no installation file. The Keychain stays.
    private func installApp() {
        let name = "ApphudIdentityTests.\(UUID().uuidString)"
        suiteNames.append(name)
        defaults = UserDefaults(suiteName: name)
        installRecords = FakeInstallRecords()
    }

    private func deleteAndReinstallApp() {
        installApp()
    }

    /// Another phone restored from this one's backup: UserDefaults come along; the installation file
    /// (backup-excluded) and the this-device-only Keychain items don't.
    private func restoreBackupOntoAnotherPhone() {
        let backup = defaults.dictionaryRepresentation()
        installApp()
        backup.forEach { defaults.set($0.value, forKey: $0.key) }
        keychain = FakeKeychain()
    }

    /// State an old SDK version left: ids in UserDefaults and in after-first-unlock Keychain items.
    private func seedOldSDK(deviceID: String, userID: String, inUserDefaults: Bool = true) {
        if inUserDefaults {
            defaults.set(deviceID, forKey: "com.apphud.device_id")
            defaults.set(userID, forKey: "com.apphud.user_id")
        }
        keychain.items[.legacyDeviceID] = deviceID
        keychain.items[.legacyUserID] = userID
    }

    private func makeStore() -> ApphudIdentityStore {
        ApphudIdentityStore(defaults: defaults, keychain: keychain, installRecords: installRecords) { [unowned self] in
            idCounter += 1
            return "ID-\(idCounter)"
        }
    }

    @discardableResult
    private func launch(_ supplied: ApphudSuppliedIDs = ApphudSuppliedIDs(), file: StaticString = #filePath, line: UInt = #line) -> ApphudIdentityResolution {
        guard let resolution = makeStore().resolve(supplied) else {
            XCTFail("identity did not resolve", file: file, line: line)
            return ApphudIdentityResolution(identity: ApphudIdentity(installationID: "", anonymousID: ""), launch: .normal, changed: false)
        }
        return resolution
    }

    /// A launch on version 2 with every id from the app.
    @MainActor
    private func launchWithAppIDs(isReinstall: Bool? = nil) -> ApphudInternal {
        let sdk = ApphudInternal()
        sdk.identityStore = makeStore()
        sdk.chooseIdentityVersion(.v2)
        let supplied = ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "host-inst", isReinstall: isReinstall)
        sdk.identity = launch(supplied).identity
        sdk.appSuppliesIDs = supplied.suppliesAllIDs
        return sdk
    }

    private func customerParams(_ identity: ApphudIdentity) -> [String: Any] {
        ApphudInternal.customerIdentityParams(identity, report: makeStore().registrationReport(for: identity))
    }

    // MARK: - Identity model

    func testDefaultIDFactoryCreatesLowercaseUUIDsForVersion2() throws {
        let store = ApphudIdentityStore(defaults: defaults, keychain: keychain, installRecords: installRecords)
        var identity = try XCTUnwrap(store.resolve(ApphudSuppliedIDs())).identity
        let installationID = identity.installationID
        let anonymousID = identity.anonymousID
        store.logout(anonymousID: nil, &identity)
        for id in [installationID, anonymousID, identity.anonymousID] {
            XCTAssertNotNil(UUID(uuidString: id))
            XCTAssertEqual(id, id.lowercased())
        }
        XCTAssertEqual(identity.installationID, installationID)
        XCTAssertNotEqual(identity.anonymousID, anonymousID)
        XCTAssertEqual(try XCTUnwrap(store.resolve(ApphudSuppliedIDs())).identity, identity)
    }

    func testDefaultIDFactoryPreservesStoredAndHostIDCase() throws {
        let supplied = ApphudSuppliedIDs(userID: "Host-User-ABC", anonymousID: "AABBCCDD-AABB-CCDD-EEFF-AABBCCDDEEFF", installationID: "11223344-AABB-CCDD-EEFF-112233445566")
        let store = ApphudIdentityStore(defaults: defaults, keychain: keychain, installRecords: installRecords)
        var identity = try XCTUnwrap(store.resolve(supplied)).identity
        XCTAssertEqual(identity.installationID, supplied.installationID)
        XCTAssertEqual(identity.anonymousID, supplied.anonymousID)
        XCTAssertEqual(identity.userID, supplied.userID)
        let relaunched = ApphudIdentityStore(defaults: defaults, keychain: keychain, installRecords: installRecords)
        XCTAssertEqual(try XCTUnwrap(relaunched.resolve(ApphudSuppliedIDs())).identity, identity)
        relaunched.logout(anonymousID: "Host-New-Anonymous-ABC", &identity)
        XCTAssertEqual(identity.anonymousID, "Host-New-Anonymous-ABC")
        XCTAssertEqual(identity.installationID, supplied.installationID)
    }

    func testDefaultIDFactoryPreservesVersion1UUIDCaseAfterVersion2Logout() throws {
        let store = ApphudIdentityStore(defaults: defaults, keychain: keychain, installRecords: installRecords)
        var identity = try XCTUnwrap(store.resolve(ApphudSuppliedIDs())).identity
        store.logout(anonymousID: nil, &identity)
        let deviceID = try XCTUnwrap(store.idsForVersion1()?.deviceID)
        XCTAssertNotNil(UUID(uuidString: deviceID))
        XCTAssertEqual(deviceID, deviceID.uppercased(), "V1 keeps its existing UUID format")
    }

    func testModelFreshInstall_MintsInstallationAndAnonymousIds_NoUser() {
        let identity = launch().identity

        XCTAssertEqual(identity.installationID, "ID-1")
        XCTAssertEqual(identity.anonymousID, "ID-2")
        XCTAssertNil(identity.userID)
        XCTAssertEqual(identity.currentID, identity.anonymousID, "current identity is anonymous_id")
    }

    func testModelUpdateUserID_KeepsInstallationAndAnonymous_SetsUser() {
        var identity = launch().identity
        let before = identity

        XCTAssertEqual(makeStore().identify("Alice", &identity), .identified)

        XCTAssertEqual(identity.installationID, before.installationID)
        XCTAssertEqual(identity.anonymousID, before.anonymousID)
        XCTAssertEqual(identity.userID, "Alice")
        XCTAssertEqual(identity.currentID, "Alice", "current identity is user_id")
        XCTAssertEqual(launch().identity, identity, "persisted across relaunch")
    }

    func testModelUpdateUserIDAgain_IsNoOp() {
        var identity = launch().identity
        _ = makeStore().identify("Alice", &identity)
        let before = identity

        XCTAssertEqual(makeStore().identify("Alice", &identity), .unchanged)
        XCTAssertEqual(identity, before)
    }

    func testModelUpdateUserIDBobWhileAliceWithoutLogout_SwitchesUser_KeepsAnonymous() {
        var identity = launch().identity
        _ = makeStore().identify("Alice", &identity)
        let before = identity

        XCTAssertEqual(makeStore().identify("Bob", &identity), .switched)

        XCTAssertEqual(identity.installationID, before.installationID)
        XCTAssertEqual(identity.anonymousID, before.anonymousID, "the anonymous id stays (linked to Alice only)")
        XCTAssertEqual(identity.userID, "Bob")
        XCTAssertEqual(identity.currentID, "Bob")
    }

    func testModelLogout_KeepsInstallation_NewAnonymous_ClearsUser() {
        var identity = launch().identity
        _ = makeStore().identify("Alice", &identity)
        let before = identity

        makeStore().logout(anonymousID: nil, &identity)

        XCTAssertEqual(identity.installationID, before.installationID)
        XCTAssertNotEqual(identity.anonymousID, before.anonymousID)
        XCTAssertNil(identity.userID)
        XCTAssertEqual(identity.currentID, identity.anonymousID)
        let relaunched = launch().identity
        XCTAssertEqual(relaunched.installationID, identity.installationID)
        XCTAssertEqual(relaunched.anonymousID, identity.anonymousID)
        XCTAssertNil(relaunched.userID)
    }

    func testModelLogoutWithSuppliedAnonymousID_UsesIt() {
        var identity = launch().identity

        makeStore().logout(anonymousID: "anon-from-host", &identity)

        XCTAssertEqual(identity.anonymousID, "anon-from-host")
        XCTAssertEqual(launch().identity.anonymousID, "anon-from-host")
    }

    func testModelDeleteAndReinstall_NewInstallationAndAnonymous_NoUser() {
        var identity = launch().identity
        _ = makeStore().identify("Alice", &identity)

        deleteAndReinstallApp()
        let reinstalled = launch().identity

        XCTAssertNotEqual(reinstalled.installationID, identity.installationID)
        XCTAssertNotEqual(reinstalled.anonymousID, identity.anonymousID)
        XCTAssertNil(reinstalled.userID)
    }

    // MARK: - Launch flow

    func testFlowInstallationIDExists_NormalLaunch_WritesMissingReinstallKey() {
        installRecords.record = ApphudInstallRecord(installationID: "inst-1", isReinstall: false, reinstallDecided: true)
        defaults.set("anon-1", forKey: "com.apphud.anonymous_id")

        let resolution = launch()

        XCTAssertEqual(resolution.launch, .normal)
        XCTAssertEqual(resolution.identity.installationID, "inst-1")
        XCTAssertEqual(resolution.identity.anonymousID, "anon-1")
        XCTAssertFalse(resolution.changed)
        XCTAssertNotNil(keychain.items[.reinstall], "the key is written if missing")
    }

    func testFlowOldDeviceIDInUserDefaults_AdoptedAsInstallationID_NormalLaunch() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")

        let resolution = launch()

        XCTAssertEqual(resolution.launch, .upgrade)
        XCTAssertEqual(resolution.identity.installationID, "OLD-DEVICE")
        XCTAssertNil(resolution.identity.isReinstall, "an upgrade in place is neither a reinstall nor a first install")
        XCTAssertTrue(resolution.changed, "the backend has to see the new ids")
    }

    func testFlowNoInstallationID_ReinstallKeyExists_IsReinstall() {
        keychain.items[.reinstall] = "1"

        let identity = launch().identity

        XCTAssertEqual(identity.isReinstall, true)
    }

    func testFlowNoInstallationID_OnlyOldKeychainKey_IsFirstInstall() {
        keychain.items[.legacyDeviceID] = "OLD-DEVICE"

        XCTAssertEqual(launch().identity.isReinstall, false, "the old key moves to a new phone with a backup: no reinstall")
    }

    func testFlowNoInstallationID_OnlyOldKeychainKeyBlank_IsFirstInstall() {
        keychain.items[.legacyDeviceID] = ""

        XCTAssertEqual(launch().identity.isReinstall, false, "a blanked old key is no reinstall either")
    }

    func testFlowNoInstallationID_NothingInKeychain_IsFirstInstall() {
        let resolution = launch()

        XCTAssertEqual(resolution.launch, .newInstall)
        XCTAssertEqual(resolution.identity.isReinstall, false)
    }

    func testFlowNewInstall_KeychainLocked_UnknownThenResolvedOnLaterLaunch() {
        keychain.items[.reinstall] = "1"
        keychain.locked = true

        let first = launch().identity
        XCTAssertNil(first.isReinstall, "unknown is never taken for a first install")
        XCTAssertNil(customerParams(first)["reinstall"])

        keychain.locked = false
        let later = launch().identity

        XCTAssertEqual(later.installationID, first.installationID)
        XCTAssertEqual(later.isReinstall, true, "the first successful read decides")
    }

    func testFlowAfterDeciding_ResultSavedKeyWrittenOldKeysKept() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE", inUserDefaults: false)

        let identity = launch().identity

        XCTAssertEqual(installRecords.record?.installationID, identity.installationID)
        XCTAssertEqual(installRecords.record?.isReinstall, false, "saved next to installation_id")
        XCTAssertNotNil(keychain.items[.reinstall])
        XCTAssertEqual(keychain.items[.legacyDeviceID], "OLD-DEVICE", "kept for identity version 1")
        XCTAssertEqual(keychain.items[.legacyUserID], "OLD-DEVICE", "kept for identity version 1")
    }

    func testFlowKeyNotWrittenWhileTheReadFailed() {
        keychain.readsFail = true
        launch()
        keychain.readsFail = false

        XCTAssertNil(keychain.items[.reinstall], "written only after a successful read")
    }

    func testFlowKeyNotWrittenWhenTheRecordCouldNotBeSaved() {
        installRecords.failWrites = true

        launch()

        XCTAssertNil(keychain.items[.reinstall], "a key without a saved record would make the next launch a reinstall")
    }

    func testFlowOldKeyReadOnlyForTheFlag_NeverAdoptedAsID() {
        keychain.items[.legacyDeviceID] = "OLD-DEVICE"

        let identity = launch().identity

        XCTAssertNotEqual(identity.installationID, "OLD-DEVICE")
        XCTAssertNotEqual(identity.anonymousID, "OLD-DEVICE")
    }

    func testFlowStoredIDsUnreadable_DoesNotResolve() {
        installRecords.unreadable = true

        XCTAssertNil(makeStore().resolve(ApphudSuppliedIDs()), "never mint over ids that can't be read")
    }

    // MARK: - Reinstall detection

    func testReinstallFlagDeleteReinstall_TrueAndRegistrationsCarryReinstall() {
        launch()
        deleteAndReinstallApp()

        let identity = launch().identity

        XCTAssertEqual(identity.isReinstall, true)
        XCTAssertEqual(customerParams(identity)["reinstall"] as? Bool, true)
        let relaunch = launch()
        XCTAssertEqual(relaunch.identity.isReinstall, true)
        XCTAssertEqual(customerParams(relaunch.identity)["reinstall"] as? Bool, true, "sent until a registration succeeds")
        XCTAssertEqual(relaunch.launch, .normal, "only the install's first launch counts as new")
    }

    func testReinstallSentUntilARegistrationCarryingItSucceeds_ThenNeverAgainForTheInstall() {
        launch()
        deleteAndReinstallApp()
        var identity = launch().identity

        makeStore().markRegistered(reinstallSent: true, legacyDeviceIDSent: false)

        XCTAssertNil(customerParams(identity)["reinstall"])
        _ = makeStore().identify("Alice", &identity)
        XCTAssertNil(customerParams(identity)["reinstall"], "not after an identify")
        makeStore().logout(anonymousID: nil, &identity)
        XCTAssertNil(customerParams(identity)["reinstall"], "not after a logout: the backend records it on every customer it goes to")
        XCTAssertNil(customerParams(launch().identity)["reinstall"], "not on later launches")
        XCTAssertEqual(installRecords.record?.isReinstall, true, "the install is still a reinstall")

        deleteAndReinstallApp()
        XCTAssertEqual(customerParams(launch().identity)["reinstall"] as? Bool, true, "the next reinstall is a new install: sent again")
    }

    func testReinstallNotReportedByARegistrationThatDidNotCarryIt() {
        keychain.items[.reinstall] = "1"
        keychain.locked = true
        launch()

        makeStore().markRegistered(reinstallSent: false, legacyDeviceIDSent: false)
        keychain.locked = false

        XCTAssertEqual(customerParams(launch().identity)["reinstall"] as? Bool, true, "decided on a later launch, then sent")
    }

    func testReinstallFlagFreshInstall_FalseAndNoParam() {
        let identity = launch().identity

        XCTAssertEqual(identity.isReinstall, false)
        XCTAssertNil(customerParams(identity)["reinstall"])
    }

    func testReinstallFlagBackupRestoredOntoAnotherPhone_False() {
        // Made after the upgrade: the old keys are gone by then.
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        let original = launch().identity

        restoreBackupOntoAnotherPhone()
        let restored = launch().identity

        XCTAssertEqual(restored.isReinstall, false)
        XCTAssertNotEqual(restored.installationID, original.installationID, "the installation id is new on another phone")
    }

    func testReinstallFlagLogoutDeleteReinstall_True() {
        var identity = launch().identity
        makeStore().logout(anonymousID: nil, &identity)

        deleteAndReinstallApp()

        XCTAssertEqual(launch().identity.isReinstall, true, "logout never removes the key")
    }

    func testReinstallFlagReinstallStraightFromOldSDK_False() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE", inUserDefaults: false)

        XCTAssertEqual(launch().identity.isReinstall, false, "the old SDK wrote no reinstall key: reads as a first install")
    }

    func testReinstallFlagUpdatedThenDeletedAndReinstalled_True() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        launch()

        deleteAndReinstallApp()

        XCTAssertEqual(launch().identity.isReinstall, true)
    }

    func testReinstallFlagKeychainUnreadableAtFirstLaunch_NilNoParam_ResolvedLater() {
        keychain.locked = true
        let first = launch().identity
        XCTAssertNil(first.isReinstall)
        XCTAssertNil(customerParams(first)["reinstall"])

        keychain.locked = false
        XCTAssertEqual(launch().identity.isReinstall, false)
    }

    // MARK: - Supplied ids, upgrade, deprecated API

    func testSuppliedIDsSurviveRelaunch_NeverRotated() {
        let supplied = ApphudSuppliedIDs(userID: "Alice", anonymousID: "anon-host", installationID: "inst-host")
        launch(supplied)

        let relaunched = launch(supplied).identity
        XCTAssertEqual(relaunched.installationID, "inst-host")
        XCTAssertEqual(relaunched.anonymousID, "anon-host")
        XCTAssertEqual(relaunched.userID, "Alice")
        XCTAssertEqual(installRecords.record?.installationID, "inst-host", "a supplied installation id is persisted")
    }

    func testSuppliedInstallationIDInStandaloneModeIsPersisted() {
        // startManually(deviceID:) passes only the installation id.
        launch(ApphudSuppliedIDs(installationID: "device-from-host"))

        XCTAssertEqual(launch().identity.installationID, "device-from-host")
    }

    func testUpgradeKeepsTheCustomer_InstallationIDIsOldDeviceID() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")

        let params = customerParams(launch().identity)

        XCTAssertEqual(params["installation_id"] as? String, "OLD-DEVICE")
        XCTAssertEqual(params["anonymous_id"] as? String, "OLD-DEVICE")
        XCTAssertNil(params["user_id"], "an SDK-generated id is never sent as user_id")
        XCTAssertNil(params["device_id"])
    }

    func testUpgradeSendsTheOldDeviceIDAsLegacyUntilARegistrationSucceeds() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")

        XCTAssertEqual(customerParams(launch().identity)["legacy_device_id"] as? String, "OLD-DEVICE")
        XCTAssertEqual(customerParams(launch().identity)["legacy_device_id"] as? String, "OLD-DEVICE",
                       "a later launch still sends it: the old key is gone from UserDefaults by then")

        makeStore().markRegistered(reinstallSent: false, legacyDeviceIDSent: true)

        let identity = launch().identity
        XCTAssertNil(customerParams(identity)["legacy_device_id"])
        XCTAssertEqual(identity.installationID, "OLD-DEVICE", "installation_id stays the old device_id")
    }

    func testLegacyDeviceIDKeptByARegistrationThatDidNotCarryIt() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")
        launch()

        makeStore().markRegistered(reinstallSent: true, legacyDeviceIDSent: false)

        XCTAssertEqual(customerParams(launch().identity)["legacy_device_id"] as? String, "OLD-DEVICE")
    }

    func testNoLegacyDeviceIDOnAFreshInstallOrAReinstall() {
        XCTAssertNil(customerParams(launch().identity)["legacy_device_id"])
        deleteAndReinstallApp()
        XCTAssertNil(customerParams(launch().identity)["legacy_device_id"])
    }

    func testOldSDKDeletedThenThisOneInstalledSendsNoLegacyDeviceID() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE", inUserDefaults: false)

        XCTAssertNil(customerParams(launch().identity)["legacy_device_id"], "the Keychain's old device_id is never sent")
    }

    func testOldSDKBackupRestoredOntoAnotherPhoneSendsTheLegacyDeviceID() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        restoreBackupOntoAnotherPhone()

        XCTAssertEqual(customerParams(launch().identity)["legacy_device_id"] as? String, "OLD-DEVICE")
    }

    func testUpgradeWhoseRecordCouldNotBeSavedStillSendsTheLegacyDeviceIDThisLaunch() throws {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        installRecords.failWrites = true
        let store = makeStore()
        let identity = try XCTUnwrap(store.resolve(ApphudSuppliedIDs()))
        func legacy() -> String? {
            ApphudInternal.customerIdentityParams(identity.identity, report: store.registrationReport(for: identity.identity))["legacy_device_id"] as? String
        }

        XCTAssertEqual(identity.identity.installationID, "OLD-DEVICE")
        XCTAssertEqual(legacy(), "OLD-DEVICE", "installation_id alone adopts nothing")
        XCTAssertEqual(defaults.string(forKey: "com.apphud.device_id"), "OLD-DEVICE", "the next launch upgrades again")

        store.markRegistered(reinstallSent: false, legacyDeviceIDSent: true)
        XCTAssertNil(legacy())
    }

    func testTheOldDeviceIDGoesAfterTheFirstIdentifyOfTheSamePerson() {
        // Until the first successful registration, not after a logout or a user switch.
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        var identity = launch().identity

        _ = makeStore().identify("alice", &identity)

        XCTAssertEqual(customerParams(identity)["legacy_device_id"] as? String, "OLD-DEVICE", "the anonymous person signed in")
    }

    func testTheOldDeviceIDIsNotSentAfterAUserSwitch() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")
        var identity = launch().identity

        _ = makeStore().identify("Bob", &identity)

        XCTAssertNil(customerParams(identity)["legacy_device_id"], "the old customer is alice's")
        XCTAssertNil(customerParams(launch().identity)["legacy_device_id"], "nor on a later launch")
    }

    func testTheOldDeviceIDIsNotSentAfterALogout() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")
        var identity = launch().identity

        makeStore().logout(anonymousID: nil, &identity)

        XCTAssertNil(customerParams(identity)["legacy_device_id"], "the old customer is the logged-out person's")
        XCTAssertNil(customerParams(launch().identity)["legacy_device_id"], "nor on a later launch")
    }

    func testTheOldDeviceIDIsNotSentWhenStartResolvesAnotherUserThanTheStoredOne() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")

        let resolution = launch(ApphudSuppliedIDs(userID: "bob"))

        XCTAssertTrue(resolution.switchedUser)
        XCTAssertNil(customerParams(resolution.identity)["legacy_device_id"])
    }

    func testTheOldDeviceIDIsNotSentWhenTheAppSuppliesAnotherUser() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")
        launch()

        let supplied = launch(ApphudSuppliedIDs(userID: "dave", anonymousID: "host-anon", installationID: "OLD-DEVICE"))

        XCTAssertTrue(supplied.switchedUser)
        XCTAssertNil(customerParams(supplied.identity)["legacy_device_id"], "every id supplied")
    }

    func testUpgradeTheOldGeneratedIDThatTheAppPassesBackIsNoUser() {
        // The old SDK took a user id the server returned; the app kept the generated id it was given.
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")

        let resolution = launch(ApphudSuppliedIDs(userID: "OLD-DEVICE"))

        XCTAssertEqual(resolution.identity.userID, "alice@example.com")
        XCTAssertFalse(resolution.switchedUser, "the app passed the old SDK's own id: no switch")
        let params = customerParams(resolution.identity)
        XCTAssertEqual(params["user_id"] as? String, "alice@example.com", "never the generated id")
        XCTAssertEqual(params["legacy_device_id"] as? String, "OLD-DEVICE", "the old customer is adopted")

        let later = launch(ApphudSuppliedIDs(userID: "OLD-DEVICE"))
        XCTAssertEqual(later.identity.userID, "alice@example.com", "on later launches too")
        XCTAssertFalse(later.switchedUser)
    }

    func testUpgradeWithTheAppsOwnInstallationIDTheOldGeneratedIDIsStillNoUser() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")

        let identity = launch(ApphudSuppliedIDs(userID: "OLD-DEVICE", installationID: "host-inst")).identity

        XCTAssertEqual(identity.installationID, "host-inst")
        XCTAssertEqual(identity.userID, "alice@example.com")
        let later = launch(ApphudSuppliedIDs(userID: "OLD-DEVICE", installationID: "host-inst"))
        XCTAssertEqual(later.identity.userID, "alice@example.com", "on later launches too, with the old key gone")
        XCTAssertFalse(later.switchedUser)
    }

    func testTheOldGeneratedIDIsNeverAUser_OnIdentifyAndWithEveryIDSupplied() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")
        let store = makeStore()
        var identity = store.resolve(ApphudSuppliedIDs())!.identity

        XCTAssertEqual(store.identify("OLD-DEVICE", &identity), .unchanged)
        XCTAssertEqual(identity.userID, "alice@example.com")

        let supplied = launch(ApphudSuppliedIDs(userID: "OLD-DEVICE", anonymousID: "host-anon", installationID: "host-inst")).identity
        XCTAssertNil(supplied.userID)
    }

    func testOldGeneratedIDRestoredOntoAnotherPhoneIsStillNoUser() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")
        launch(ApphudSuppliedIDs(userID: "OLD-DEVICE"))
        restoreBackupOntoAnotherPhone()

        let identity = launch(ApphudSuppliedIDs(userID: "OLD-DEVICE")).identity

        XCTAssertEqual(identity.userID, "alice@example.com")
    }

    func testAUserIDTheAppChoseStaysAUserEvenWhenItIsTheInstallationID() {
        XCTAssertEqual(launch(ApphudSuppliedIDs(userID: "U", installationID: "U")).identity.userID, "U")
        installApp()
        XCTAssertEqual(launch(ApphudSuppliedIDs(userID: "U", anonymousID: "host-anon", installationID: "U")).identity.userID, "U")
    }

    func testUpgradeSDKGeneratedLegacyUserIDBecomesAnonymousID() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")

        let identity = launch().identity

        XCTAssertEqual(identity.anonymousID, "OLD-DEVICE")
        XCTAssertNil(identity.userID)
        XCTAssertEqual(defaults.string(forKey: "com.apphud.device_id"), "OLD-DEVICE", "kept for identity version 1")
    }

    func testBackupOfAnUpdatedInstallStartsFreshOnAnotherPhone() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        let updated = launch().identity
        restoreBackupOntoAnotherPhone()
        // The old after-first-unlock Keychain items can travel with an encrypted backup.
        keychain.items[.legacyDeviceID] = "OLD-DEVICE"
        keychain.items[.legacyUserID] = "OLD-DEVICE"

        let resolution = launch()

        XCTAssertEqual(resolution.launch, .newInstall, "the kept device_id is no update")
        XCTAssertNotEqual(resolution.identity.installationID, updated.installationID)
        XCTAssertEqual(resolution.identity.anonymousID, updated.anonymousID, "UserDefaults came with the backup")
        XCTAssertEqual(resolution.identity.isReinstall, false, "the old items came with the backup: no reinstall")
        XCTAssertNil(customerParams(resolution.identity)["legacy_device_id"])
        XCTAssertNil(customerParams(resolution.identity)["reinstall"])
    }

    func testBackupRestoredWithOldKeychainItemsStaysNoReinstallOnALaterLaunch() {
        launch()
        restoreBackupOntoAnotherPhone()
        keychain.items[.legacyDeviceID] = "OLD-DEVICE"
        keychain.locked = true
        XCTAssertNil(launch().identity.isReinstall)

        keychain.locked = false

        XCTAssertEqual(launch().identity.isReinstall, false, "decided later, the old items still don't count")
    }

    func testUpgradeRealLegacyUserIDStaysUserID() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")

        let identity = launch().identity

        XCTAssertEqual(identity.installationID, "OLD-DEVICE")
        XCTAssertEqual(identity.userID, "alice@example.com")
        XCTAssertNotEqual(identity.anonymousID, "OLD-DEVICE")
        XCTAssertEqual(customerParams(identity)["user_id"] as? String, "alice@example.com")
    }

    func testUpgradeKeepsTheOldKeychainItemsNextToTheReinstallKey() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")

        launch()

        XCTAssertEqual(Set(keychain.items.keys), [.reinstall, .legacyDeviceID, .legacyUserID])
        XCTAssertEqual(keychain.items[.legacyDeviceID], "OLD-DEVICE")
        XCTAssertEqual(keychain.items[.legacyUserID], "OLD-DEVICE")
    }

    @MainActor
    @available(*, deprecated)
    func testDeprecatedDeviceIDReturnsInstallationID() {
        let saved = ApphudInternal.shared.identity
        defer { ApphudInternal.shared.identity = saved }
        ApphudInternal.shared.identity = ApphudIdentity(installationID: "inst-1", anonymousID: "anon-1")

        XCTAssertEqual(Apphud.deviceID(), "inst-1")
        XCTAssertEqual(Apphud.installationID(), "inst-1")
        XCTAssertEqual(Apphud.anonymousID(), "anon-1")
        XCTAssertEqual(Apphud.userID(), "anon-1", "an anonymous user's current identity is the anonymous id")
        // startManually(deviceID:) still compiles as an alias.
        let compileCheck: () -> Void = { Apphud.startManually(apiKey: "", userID: nil, deviceID: "inst-1") }
        _ = compileCheck
    }

    // MARK: - Request fields

    func testCustomersRequestCarriesNewIDsOnly() {
        var identity = launch().identity

        var params = customerParams(identity)
        XCTAssertEqual(params["installation_id"] as? String, identity.installationID)
        XCTAssertEqual(params["anonymous_id"] as? String, identity.anonymousID)
        XCTAssertNil(params["device_id"])
        XCTAssertNil(params["user_id"], "absent until identified")

        _ = makeStore().identify("Alice", &identity)
        params = customerParams(identity)
        XCTAssertEqual(params["user_id"] as? String, "Alice")
        XCTAssertEqual(params["anonymous_id"] as? String, identity.anonymousID, "anonymous_id goes on after identify")
    }

    @MainActor
    func testSubscriptionsRequestCarriesRestoreAndTheLegacyDeviceIDUntilARegistrationSucceeds() {
        let sdk = ApphudInternal.shared
        let saved = sdk.identity
        let savedStore = sdk.identityStore
        defer {
            sdk.identity = saved
            sdk.identityStore = savedStore
        }
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")
        sdk.identityStore = makeStore()
        sdk.identity = launch().identity

        let params = sdk.subscriptionIdentityParams(restore: false)
        XCTAssertEqual(params["restore"] as? Bool, false, "sent on every submission")
        XCTAssertEqual(params["legacy_device_id"] as? String, "OLD-DEVICE")
        XCTAssertEqual(params["installation_id"] as? String, "OLD-DEVICE")
        XCTAssertEqual(params["user_id"] as? String, "alice@example.com")
        XCTAssertNil(params["device_id"])
        XCTAssertEqual(sdk.subscriptionIdentityParams(restore: true)["restore"] as? Bool, true)

        sdk.identityStore.markRegistered(reinstallSent: false, legacyDeviceIDSent: true)

        XCTAssertNil(sdk.subscriptionIdentityParams(restore: false)["legacy_device_id"])
    }

    @MainActor
    func testEveryRequestSendsInstallationAndAnonymousIDsInsteadOfDeviceID() {
        let saved = ApphudInternal.shared.identity
        defer { ApphudInternal.shared.identity = saved }
        let sdk = ApphudInternal.shared

        sdk.identity = ApphudIdentity(installationID: "inst-1", anonymousID: "anon-1")
        XCTAssertEqual(sdk.identityParams(), ["installation_id": "inst-1", "anonymous_id": "anon-1"])
        XCTAssertEqual(sdk.identityParams(includeUserID: true), ["installation_id": "inst-1", "anonymous_id": "anon-1"],
                       "no user_id before identify")

        sdk.identity = ApphudIdentity(installationID: "inst-1", anonymousID: "anon-1", userID: "Alice")
        XCTAssertEqual(sdk.identityParams(), ["installation_id": "inst-1", "anonymous_id": "anon-1"],
                       "user_id only where it went before")
        XCTAssertEqual(sdk.identityParams(includeUserID: true)["user_id"], "Alice")
    }

    @MainActor
    func testCustomersRequestBody() {
        let sdk = ApphudInternal.shared
        let saved = sdk.identity
        let savedStore = sdk.identityStore
        defer {
            sdk.identity = saved
            sdk.identityStore = savedStore
        }
        sdk.identityStore = makeStore()

        sdk.identity = ApphudIdentity(installationID: "inst-1", anonymousID: "anon-1", userID: nil, isReinstall: true)
        var body = sdk.customerRequestParams(fields: ["initial_call": true])
        XCTAssertEqual(body["installation_id"] as? String, "inst-1")
        XCTAssertEqual(body["anonymous_id"] as? String, "anon-1")
        XCTAssertEqual(body["reinstall"] as? Bool, true)
        XCTAssertNil(body["device_id"])
        XCTAssertNil(body["user_id"])
        XCTAssertNotNil(body["first_seen"], "sent with reinstall")

        sdk.identity = ApphudIdentity(installationID: "inst-1", anonymousID: "anon-1", userID: "Alice", isReinstall: false)
        body = sdk.customerRequestParams(fields: [:])
        XCTAssertEqual(body["user_id"] as? String, "Alice")
        XCTAssertNil(body["reinstall"])
    }

    @MainActor
    func testWeb2WebByEmailGoesWithTheUsualIDs() {
        let sdk = ApphudInternal.shared
        let saved = sdk.identity
        let savedStore = sdk.identityStore
        defer {
            sdk.identity = saved
            sdk.identityStore = savedStore
        }
        sdk.identityStore = makeStore()
        sdk.identity = ApphudIdentity(installationID: "inst-1", anonymousID: "anon-1", userID: nil, isReinstall: true)

        let body = sdk.customerRequestParams(fields: ["from_web2web": true, "email": "a@b.c"])

        XCTAssertEqual(body["installation_id"] as? String, "inst-1")
        XCTAssertEqual(body["anonymous_id"] as? String, "anon-1")
        XCTAssertNil(body["device_id"], "v4 refuses device_id")
        XCTAssertNil(body["user_id"], "an anonymous person has none")
        XCTAssertEqual(body["from_web2web"] as? Bool, true)
        XCTAssertEqual(body["email"] as? String, "a@b.c")
        XCTAssertEqual(body["reinstall"] as? Bool, true, "a registration like any other")
    }

    @MainActor
    func testRegistrationFinished_SuccessStopsWhatItReported_FailureKeepsIt() {
        let sdk = ApphudInternal.shared
        let saved = sdk.identity
        let savedStore = sdk.identityStore
        defer {
            sdk.identity = saved
            sdk.identityStore = savedStore
        }
        let store = makeStore()
        sdk.identityStore = store
        installRecords.record = ApphudInstallRecord(installationID: "inst-1", isReinstall: true, reinstallDecided: true,
                                                    legacyDeviceID: "OLD-DEVICE")
        defaults.set(true, forKey: ApphudIdentityStore.syncPendingKey)
        let sent = ApphudIdentity(installationID: "inst-1", anonymousID: "anon-1", isReinstall: true)
        sdk.identity = sent
        let params = sdk.customerRequestParams(fields: [:])
        XCTAssertEqual(params["reinstall"] as? Bool, true)
        XCTAssertEqual(params["legacy_device_id"] as? String, "OLD-DEVICE")

        sdk.registrationFinished(done: false, params: params, sent: sent)
        XCTAssertEqual(store.registrationReport(for: sent), ApphudRegistrationReport(reinstall: true, legacyDeviceID: "OLD-DEVICE"),
                       "a failed registration reported nothing")
        XCTAssertTrue(store.isSyncPending)

        sdk.identity.userID = "Alice"
        sdk.registrationFinished(done: true, params: params, sent: sent)
        XCTAssertEqual(store.registrationReport(for: sdk.identity), ApphudRegistrationReport(reinstall: false, legacyDeviceID: nil),
                       "reported though an identify happened while it was out")
        XCTAssertTrue(store.isSyncPending, "the identify is still unsent")

        sdk.registrationFinished(done: true, params: sdk.customerRequestParams(fields: [:]), sent: sdk.identity)
        XCTAssertFalse(store.isSyncPending)
    }

    @MainActor
    func testTheFirstLaunchAfterAnUpdateHoldsRequestsUntilARegistrationAnswers() {
        let sdk = ApphudInternal.shared
        let saved = (sdk.identity, sdk.identityStore)
        let hold = ApphudHttpClient.shared.firstRegistrationHold
        defer {
            sdk.identity = saved.0
            sdk.identityStore = saved.1
            hold.open()
        }
        sdk.identityStore = makeStore()
        sdk.identity = ApphudIdentity(installationID: "inst-1", anonymousID: "anon-1")

        sdk.holdRequestsIfTheBackendDoesNotKnowThisInstallation()
        XCTAssertFalse(hold.isClosed, "an installation the backend knows")

        installRecords.record = ApphudInstallRecord(installationID: "OLD-DEVICE", isReinstall: nil, reinstallDecided: true,
                                                    legacyDeviceID: "OLD-DEVICE")
        sdk.holdRequestsIfTheBackendDoesNotKnowThisInstallation()
        XCTAssertTrue(hold.isClosed, "the first launch after an update")

        sdk.registrationFinished(done: false, params: [:], sent: sdk.identity)
        XCTAssertFalse(hold.isClosed, "a registration that failed releases them too")
    }

    @MainActor
    func testRegistrationFinished_ASuccessThatCarriedNeitherReportsNeither() {
        let sdk = ApphudInternal.shared
        let saved = sdk.identity
        let savedStore = sdk.identityStore
        defer {
            sdk.identity = saved
            sdk.identityStore = savedStore
        }
        let store = makeStore()
        sdk.identityStore = store
        installRecords.record = ApphudInstallRecord(installationID: "inst-1", isReinstall: true, reinstallDecided: true,
                                                    legacyDeviceID: "OLD-DEVICE")
        let sent = ApphudIdentity(installationID: "inst-1", anonymousID: "anon-1", isReinstall: true)
        sdk.identity = sent

        sdk.registrationFinished(done: true, params: ["installation_id": "inst-1", "anonymous_id": "anon-1"], sent: sent)

        XCTAssertEqual(store.registrationReport(for: sent), ApphudRegistrationReport(reinstall: true, legacyDeviceID: "OLD-DEVICE"))
    }

    func testWeb2WebByEmailAdoptsOnlyAnotherCustomerFromItsOwnResponse() {
        func response(customerID: String, userID: String) -> Data {
            Data(#"{"data":{"results":{"id":"\#(customerID)","user_id":"\#(userID)"}}}"#.utf8)
        }

        let sent = ApphudIdentity(installationID: "inst-1", anonymousID: "anon-1")
        func adopt(_ data: Data?, current: ApphudIdentity = sent) -> String? {
            ApphudInternal.webUserToAdopt(customerBefore: "cust-1", sent: sent, current: current, responseData: data)
        }

        XCTAssertEqual(adopt(response(customerID: "cust-web", userID: "web-user")), "web-user")
        var answered = sent
        answered.isReinstall = true
        XCTAssertEqual(adopt(response(customerID: "cust-web", userID: "web-user"), current: answered), "web-user",
                       "the app's reinstall answer came while the request was out: the ids are the same")
        XCTAssertNil(adopt(response(customerID: "cust-1", userID: "other-install")),
                     "no match: the same customer comes back, its user_id may be another install's id")
        XCTAssertNil(adopt(response(customerID: "cust-web", userID: "anon-1")))
        XCTAssertNil(adopt(nil))
        XCTAssertNil(adopt(response(customerID: "cust-web", userID: "web-user"), current: ApphudIdentity(installationID: "inst-1", anonymousID: "anon-2")),
                     "a logout while the request was out: the new anonymous person is not the web user")
    }

    func testAppAccountTokenIsTheInstallationIDUnlessTheUserIDIsAUUID() {
        let installationID = "6F9619FF-8B86-D011-B42D-00C04FC964FF"
        let anonymousID = "0C1D2E3F-4A5B-4C6D-8E7F-9A0B1C2D3E4F"
        let userUUID = "2F8AE6A1-B7C5-4966-8DF8-89F750012506"
        func username(_ userID: String?) -> String {
            ApphudStoreKitWrapper.applicationUsername(for: ApphudIdentity(installationID: installationID, anonymousID: anonymousID, userID: userID))
        }

        XCTAssertEqual(username(nil), installationID, "anonymous: the backend loses the anonymous id after identify and merge")
        XCTAssertEqual(username("alice@example.com"), installationID)
        XCTAssertEqual(username(userUUID), userUUID)
    }

    #if os(iOS)
    /// "IDFV is sent automatically as a separate field, respecting `optOutOfTracking`."
    @MainActor
    func testIDFVIsSentWithoutTheHostUnlessOptedOut() throws {
        let sdk = ApphudInternal.shared
        let savedIdentifiers = sdk.deviceIdentifiers
        let savedOptOut = ApphudUtils.shared.optOutOfTracking
        defer {
            sdk.deviceIdentifiers = savedIdentifiers
            ApphudUtils.shared.optOutOfTracking = savedOptOut
        }
        sdk.deviceIdentifiers = (nil, nil)
        let systemIDFV = try XCTUnwrap(UIDevice.current.identifierForVendor?.uuidString)

        ApphudUtils.shared.optOutOfTracking = false
        XCTAssertEqual(sdk.customerRequestParams(fields: [:])["idfv"] as? String, systemIDFV,
                       "POST /v4/customers carries the IDFV the host never passed")

        ApphudUtils.shared.optOutOfTracking = true
        XCTAssertNil(sdk.customerRequestParams(fields: [:])["idfv"])
    }
    #endif

    private func embeddedIDs(userID: String? = nil) -> ApphudSuppliedIDs {
        ApphudSuppliedIDs(userID: userID, anonymousID: "host-anon", installationID: "host-install")
    }

    func testEmbeddedUpgradeSendsStoredLegacyIDWithoutReplacingHostIDs() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "old-real-user")
        let before = keychain.items
        let result = launch(embeddedIDs())
        XCTAssertEqual(result.launch, .upgrade)
        XCTAssertEqual(customerParams(result.identity)["legacy_device_id"] as? String, "OLD-DEVICE")
        XCTAssertEqual(result.identity.installationID, "host-install")
        XCTAssertEqual(result.identity.anonymousID, "host-anon")
        XCTAssertNil(result.identity.userID)
        XCTAssertEqual(defaults.string(forKey: "com.apphud.device_id"), "OLD-DEVICE")
        XCTAssertEqual(keychain.accessCount, 0)
        XCTAssertEqual(keychain.items, before)
        XCTAssertEqual(idCounter, 0)
    }

    func testEmbeddedCoreUpgradeAlsoSendsLegacyIDWithoutDependingOnUserIDSearch() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "host-anon")
        let result = launch(embeddedIDs())
        XCTAssertEqual(customerParams(result.identity)["legacy_device_id"] as? String, "OLD-DEVICE")
        XCTAssertNil(result.identity.userID)
        XCTAssertFalse(result.switchedUser)
    }

    func testEmbeddedRealUserEqualToNewHostAnonymousIDStillSwitchesToAnotherRealUser() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "host-anon")
        let result = launch(embeddedIDs(userID: "Bob"))
        XCTAssertTrue(result.switchedUser)
        XCTAssertEqual(result.identity.userID, "Bob")
        XCTAssertNil(customerParams(result.identity)["legacy_device_id"], "Core's old real user must not be guessed to be generated")
    }

    func testEmbeddedFirstIdentifyOfOldGeneratedUserIsNotAnAccountSwitch() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        let result = launch(embeddedIDs(userID: "Alice"))
        XCTAssertFalse(result.switchedUser)
        XCTAssertEqual(result.identity.userID, "Alice")
        XCTAssertEqual(customerParams(result.identity)["legacy_device_id"] as? String, "OLD-DEVICE")
    }

    func testEmbeddedOldGeneratedIDPassedAsUserIsNotPromotedToRealUser() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        let result = launch(embeddedIDs(userID: "OLD-DEVICE"))
        XCTAssertNil(result.identity.userID)
        XCTAssertFalse(result.switchedUser)
        XCTAssertEqual(customerParams(result.identity)["legacy_device_id"] as? String, "OLD-DEVICE")
    }

    func testEmbeddedPendingLegacyIDSurvivesRelaunchUntilCarryingRegistrationSucceeds() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "old-real-user")
        _ = launch(embeddedIDs())
        var next = launch(embeddedIDs())
        XCTAssertEqual(customerParams(next.identity)["legacy_device_id"] as? String, "OLD-DEVICE")
        makeStore().markRegistered(reinstallSent: false, legacyDeviceIDSent: false, installationID: "host-install")
        XCTAssertEqual(customerParams(next.identity)["legacy_device_id"] as? String, "OLD-DEVICE")
        makeStore().markRegistered(reinstallSent: false, legacyDeviceIDSent: true, installationID: "host-install")
        next = launch(embeddedIDs())
        XCTAssertNil(customerParams(next.identity)["legacy_device_id"])
        XCTAssertEqual(defaults.string(forKey: "com.apphud.device_id"), "OLD-DEVICE", "V1 rollback data stays")
        let another = launch(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "another-host-install"))
        XCTAssertNil(customerParams(another.identity)["legacy_device_id"], "retained V1 defaults are not a new migration")
    }

    func testEmbeddedFailedRecordWriteRetainsLegacyAcrossProcessRelaunch() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "old-real-user")
        installRecords.failWrites = true
        let store = makeStore()
        let first = store.resolve(embeddedIDs())!
        XCTAssertEqual(store.registrationReport(for: first.identity).legacyDeviceID, "OLD-DEVICE")
        let restarted = makeStore()
        let next = restarted.resolve(embeddedIDs())!
        XCTAssertEqual(restarted.registrationReport(for: next.identity).legacyDeviceID, "OLD-DEVICE")
        installRecords.failWrites = false
        let saved = launch(embeddedIDs())
        XCTAssertEqual(customerParams(saved.identity)["legacy_device_id"] as? String, "OLD-DEVICE")
    }

    func testEmbeddedVersion1ReturnWithFailedRecordWriteUsesCurrentLegacyDevice() {
        let previous = launch(embeddedIDs()).identity
        runVersion1(deviceID: "V1-DEVICE", userID: "V1-DEVICE")
        installRecords.failWrites = true
        let store = makeStore()
        let result = store.resolve(embeddedIDs())!
        XCTAssertEqual(result.identity.installationID, previous.installationID)
        XCTAssertEqual(store.registrationReport(for: result.identity).legacyDeviceID, "V1-DEVICE")
    }

    func testEmbeddedAcknowledgementWithFailedRecordWriteStopsLegacyInThisProcess() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "old-real-user")
        let store = makeStore()
        let result = store.resolve(embeddedIDs())!
        XCTAssertEqual(store.registrationReport(for: result.identity).legacyDeviceID, "OLD-DEVICE")
        installRecords.failWrites = true
        store.markRegistered(reinstallSent: false, legacyDeviceIDSent: true, installationID: "host-install")
        XCTAssertNil(store.registrationReport(for: result.identity).legacyDeviceID)
    }

    func testEmbeddedSwitchWithFailedRecordWriteDoesNotAdoptPreviousUserOnRelaunch() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "Alice")
        _ = launch(embeddedIDs(userID: "Alice"))
        XCTAssertEqual(installRecords.record?.legacyDeviceID, "OLD-DEVICE")
        installRecords.failWrites = true
        let store = makeStore()
        let other = store.resolve(embeddedIDs(userID: "Bob"))!
        XCTAssertTrue(other.switchedUser)
        XCTAssertNil(store.registrationReport(for: other.identity).legacyDeviceID)
        let restarted = makeStore()
        let again = restarted.resolve(embeddedIDs(userID: "Bob"))!
        XCTAssertNil(restarted.registrationReport(for: again.identity).legacyDeviceID)
    }

    func testEmbeddedVersion1ReturnWithStableHostIDsStillRegistersNewLegacyMetadata() {
        let first = launch(embeddedIDs()).identity
        makeStore().markSynced()
        runVersion1(deviceID: "V1-DEVICE", userID: first.anonymousID)
        makeStore().markSynced()
        let next = launch(embeddedIDs())
        XCTAssertEqual(next.identity, first)
        XCTAssertTrue(next.changed)
        XCTAssertTrue(makeStore().isSyncPending)
        XCTAssertEqual(customerParams(next.identity)["legacy_device_id"] as? String, "V1-DEVICE")
        XCTAssertFalse(next.switchedUser)
    }

    func testEmbeddedReturnAfterVersion1LogoutAdoptsItsNewCurrentDeviceNotThePreviousPerson() {
        _ = launch(embeddedIDs())
        makeStore().markVersion1LoggedOut()
        runVersion1(deviceID: "NEW-V1-PERSON", userID: "NEW-V1-PERSON", tookOverVersion2: false)
        let supplied = ApphudSuppliedIDs(anonymousID: "new-host-anon", installationID: "host-install")
        let result = launch(supplied)
        XCTAssertFalse(result.switchedUser)
        XCTAssertEqual(customerParams(result.identity)["legacy_device_id"] as? String, "NEW-V1-PERSON")
        XCTAssertEqual(result.identity.anonymousID, "new-host-anon")
        XCTAssertNil(result.identity.userID)
        XCTAssertFalse(defaults.bool(forKey: ApphudIdentityStore.version1LoggedOutKey))
        XCTAssertEqual(keychain.accessCount, 0)
        XCTAssertEqual(customerParams(launch(supplied).identity)["legacy_device_id"] as? String, "NEW-V1-PERSON")
    }

    func testEmbeddedRealHostUserEqualToInstallationIDSurvivesVersion1RoundTrip() {
        let first = launch(embeddedIDs(userID: "host-install")).identity
        runVersion1(deviceID: first.installationID, userID: "host-install")
        let next = launch(embeddedIDs(userID: "host-install"))
        XCTAssertEqual(next.identity.userID, "host-install")
        XCTAssertFalse(next.switchedUser)
        makeStore().markRegistered(reinstallSent: false, legacyDeviceIDSent: true, installationID: first.installationID)
        XCTAssertEqual(launch(embeddedIDs(userID: "host-install")).identity.userID, "host-install")
    }

    func testEmbeddedCurrentVersion1GeneratedIDIsNeverPromotedAfterAcknowledgementAndRelaunch() {
        seedOldSDK(deviceID: "FIRST-DEVICE", userID: "FIRST-DEVICE")
        _ = launch(embeddedIDs())
        makeStore().markRegistered(reinstallSent: false, legacyDeviceIDSent: true, installationID: "host-install")
        runVersion1(deviceID: "CURRENT-V1-DEVICE", userID: "CURRENT-V1-DEVICE")
        let store = makeStore()
        var current = store.resolve(embeddedIDs(userID: "CURRENT-V1-DEVICE"))!.identity
        XCTAssertNil(current.userID)
        store.markRegistered(reinstallSent: false, legacyDeviceIDSent: true, installationID: current.installationID)
        XCTAssertEqual(store.identify("CURRENT-V1-DEVICE", &current), .unchanged)
        XCTAssertNil(current.userID)
        XCTAssertNil(launch(embeddedIDs(userID: "CURRENT-V1-DEVICE")).identity.userID)
        XCTAssertNil(launch(embeddedIDs(userID: "FIRST-DEVICE")).identity.userID)
    }

    func testEmbeddedPreMarkerVersion2RecordNeverResurrectsRollbackDeviceID() {
        _ = launch(embeddedIDs())
        defaults.set("ROLLBACK-DEVICE", forKey: "com.apphud.device_id")
        defaults.removeObject(forKey: "com.apphud.identity_version")
        let next = launch(embeddedIDs())
        XCTAssertEqual(next.launch, .normal)
        XCTAssertNil(customerParams(next.identity)["legacy_device_id"])
    }

    func testEmbeddedHostReportedReinstallDropsPendingOldCustomer() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "old-real-user")
        let first = launch(embeddedIDs())
        XCTAssertEqual(customerParams(first.identity)["legacy_device_id"] as? String, "OLD-DEVICE")
        let reinstall = ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "host-install", isReinstall: true)
        let next = launch(reinstall)
        XCTAssertNil(customerParams(next.identity)["legacy_device_id"])
        XCTAssertNil(customerParams(launch(reinstall).identity)["legacy_device_id"])
    }

    // MARK: - Ids supplied by the app

    func testSuppliedIDsTakeIsReinstallFromTheAppAndNeverTouchKeychain() {
        keychain.items[.legacyDeviceID] = "HOST-OLD"

        let identity = launch(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "host-inst", isReinstall: true)).identity

        XCTAssertEqual(identity.isReinstall, true)
        XCTAssertEqual(keychain.accessCount, 0, "no detection of its own when the app supplies the ids")
        XCTAssertEqual(keychain.items[.legacyDeviceID], "HOST-OLD", "the old key is left alone")
    }

    func testSuppliedIDsUnknownReinstallFromTheAppSendsNoParam() {
        let identity = launch(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "host-inst", isReinstall: nil)).identity

        XCTAssertNil(identity.isReinstall)
        XCTAssertNil(customerParams(identity)["reinstall"])
        XCTAssertEqual(keychain.accessCount, 0)
    }

    @MainActor
    func testAReinstallAnswerAfterStartGoesWithTheNextRegistration() {
        let sdk = launchWithAppIDs()
        XCTAssertNil(customerParams(sdk.identity)["reinstall"])
        makeStore().markSynced()

        sdk.setReinstall(true)

        XCTAssertEqual(sdk.isReinstall, true)
        XCTAssertEqual(customerParams(sdk.identity)["reinstall"] as? Bool, true)
        XCTAssertTrue(makeStore().isSyncPending, "the next registration isn't skipped, on a later launch either")
    }

    @MainActor
    func testAReinstallAnswerOfFalseSendsNothing() {
        let sdk = launchWithAppIDs()
        makeStore().markSynced()

        sdk.setReinstall(false)

        XCTAssertEqual(sdk.isReinstall, false)
        XCTAssertNil(customerParams(sdk.identity)["reinstall"])
        XCTAssertFalse(makeStore().isSyncPending)
    }

    @MainActor
    func testTheLatestReinstallAnswerWins() {
        let sdk = launchWithAppIDs()

        sdk.setReinstall(true)
        sdk.setReinstall(false)

        XCTAssertNil(customerParams(sdk.identity)["reinstall"])
    }

    @MainActor
    func testAReinstallAnswerAfterTheReinstallWasReportedSendsNothing() {
        let sdk = launchWithAppIDs(isReinstall: true)
        makeStore().markRegistered(reinstallSent: true, legacyDeviceIDSent: false)
        makeStore().markSynced()

        sdk.setReinstall(true)

        XCTAssertNil(customerParams(sdk.identity)["reinstall"], "once per install")
        XCTAssertFalse(makeStore().isSyncPending)
    }

    @MainActor
    func testAReinstallAnswerIsIgnoredWhenTheSDKGeneratesTheIDs() {
        let sdk = ApphudInternal()
        sdk.identityStore = makeStore()
        sdk.chooseIdentityVersion(.v2)
        sdk.identity = launch().identity
        makeStore().markSynced()

        sdk.setReinstall(true)

        XCTAssertEqual(sdk.isReinstall, false, "the SDK's own check decides")
        XCTAssertFalse(makeStore().isSyncPending)
    }

    @MainActor
    func testAReinstallAnswerIsIgnoredOnVersion1() {
        let sdk = launchWithAppIDs()
        sdk.identityVersion = .v1

        sdk.setReinstall(true)

        XCTAssertNil(sdk.isReinstall)
    }

    func testAReinstallPassedAtStartGoesUntilARegistrationCarriesIt() {
        let supplied = ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "host-inst", isReinstall: true)
        _ = launch(supplied)
        makeStore().markSynced()

        _ = launch(supplied)
        XCTAssertTrue(makeStore().isSyncPending, "the registration of this launch isn't skipped")

        makeStore().markRegistered(reinstallSent: true, legacyDeviceIDSent: false)
        makeStore().markSynced()
        _ = launch(supplied)
        XCTAssertFalse(makeStore().isSyncPending, "reported: nothing more to send")
    }

    @MainActor
    func testAReinstallAnswerAfterStartReachesALaterLaunch() {
        let sdk = launchWithAppIDs()
        sdk.setReinstall(true)
        // The registration of this launch had gone out before the answer.
        makeStore().markSynced()

        let next = launch(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "host-inst", isReinstall: nil))

        XCTAssertEqual(next.identity.isReinstall, true)
        XCTAssertEqual(customerParams(next.identity)["reinstall"] as? Bool, true)
        XCTAssertTrue(makeStore().isSyncPending, "the registration of that launch isn't skipped")
    }

    @MainActor
    func testTheAppsLatestReinstallAnswerIsKept() {
        let sdk = launchWithAppIDs()
        sdk.setReinstall(true)
        sdk.setReinstall(false)

        let next = launch(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "host-inst"))
        XCTAssertEqual(next.identity.isReinstall, false)
        XCTAssertNil(customerParams(next.identity)["reinstall"])

        let passed = launch(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "host-inst", isReinstall: true))
        XCTAssertEqual(passed.identity.isReinstall, true, "an answer passed to start replaces the kept one")
    }

    func testAKeptReinstallAnswerBelongsToItsInstallation() {
        _ = launch(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "inst-A", isReinstall: true))

        let other = launch(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "inst-B"))

        XCTAssertNil(other.identity.isReinstall)
        XCTAssertNil(customerParams(other.identity)["reinstall"])
    }

    func testReportedReinstallOnPreviousHostInstallationCannotSuppressNewInstallAtStart() {
        _ = launch(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "inst-A", isReinstall: true))
        makeStore().markRegistered(reinstallSent: true, legacyDeviceIDSent: false)
        makeStore().markSynced()

        let next = launch(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "inst-B", isReinstall: true))

        XCTAssertEqual(customerParams(next.identity)["reinstall"] as? Bool, true)
        XCTAssertTrue(makeStore().isSyncPending)
        makeStore().markRegistered(reinstallSent: true, legacyDeviceIDSent: false)
        makeStore().markSynced()
        XCTAssertNil(customerParams(next.identity)["reinstall"], "ACK belongs to the new install now")
        _ = launch(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "inst-B", isReinstall: true))
        XCTAssertFalse(makeStore().isSyncPending, "same-install ACK still suppresses retries")
    }

    @MainActor
    func testReportedReinstallOnPreviousHostInstallationCannotSuppressLateNewAnswer() {
        let sdk = launchWithAppIDs(isReinstall: true)
        sdk.identityStore.markRegistered(reinstallSent: true, legacyDeviceIDSent: false, installationID: sdk.currentInstallationID)
        sdk.identityStore.markSynced()
        sdk.identity = sdk.identityStore.resolve(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "next-host-inst"))!.identity
        sdk.identityStore.markSynced()
        XCTAssertNil(sdk.isReinstall)

        sdk.setReinstall(true)

        XCTAssertTrue(sdk.identityStore.isSyncPending)
        XCTAssertTrue(sdk.identityStore.registrationReport(for: sdk.identity).reinstall)
        XCTAssertNil(installRecords.record?.reinstallReported, "previous installation's ACK must be discarded")
        let relaunch = launch(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "next-host-inst"))
        XCTAssertEqual(customerParams(relaunch.identity)["reinstall"] as? Bool, true, "late answer survives relaunch")
    }

    @MainActor
    func testPreviousHostInstallACKCannotSuppressNewAnswerWhenNewRecordWriteFails() {
        let sdk = launchWithAppIDs(isReinstall: true)
        sdk.identityStore.markRegistered(reinstallSent: true, legacyDeviceIDSent: false, installationID: sdk.currentInstallationID)
        installRecords.failWrites = true
        sdk.identity = sdk.identityStore.resolve(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "next-host-inst", isReinstall: true))!.identity
        XCTAssertTrue(sdk.identityStore.registrationReport(for: sdk.identity).reinstall)
        sdk.identityStore.markSynced()

        sdk.setReinstall(true)

        XCTAssertTrue(sdk.identityStore.isSyncPending)
        XCTAssertTrue(sdk.identityStore.registrationReport(for: sdk.identity).reinstall)
        XCTAssertEqual(installRecords.record?.installationID, "host-inst", "failed write retained the foreign record")
    }

    @MainActor
    func testNewHostAnswerAndACKNeverUpdateThePreviousInstallRecordAfterFailedWrite() {
        let sdk = launchWithAppIDs(isReinstall: false)
        let previous = installRecords.record
        installRecords.failWrites = true
        sdk.identity = sdk.identityStore.resolve(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "next-host-inst"))!.identity
        installRecords.failWrites = false

        sdk.setReinstall(true)
        XCTAssertEqual(installRecords.record, previous, "new host answer cannot edit another installation")
        XCTAssertTrue(sdk.identityStore.registrationReport(for: sdk.identity).reinstall)
        sdk.identityStore.markRegistered(reinstallSent: true, legacyDeviceIDSent: false, installationID: sdk.currentInstallationID)
        sdk.identityStore.markSynced()

        XCTAssertEqual(installRecords.record, previous, "new installation ACK cannot be written to the previous one")
        XCTAssertFalse(sdk.identityStore.registrationReport(for: sdk.identity).reinstall, "accepted in-memory ACK still suppresses repeats")
        sdk.setReinstall(true)
        XCTAssertFalse(sdk.identityStore.isSyncPending)
    }

    @MainActor
    func testAReinstallAnswerWhileStartWaitsForTheFirstUnlockGoesWithIt() {
        let sdk = ApphudInternal()
        sdk.chooseIdentityVersion(.v2)
        sdk.delayedInitilizationParams = ("key", ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "host-inst"), false)

        sdk.setReinstall(true)

        XCTAssertEqual(sdk.delayedInitilizationParams?.supplied.isReinstall, true)
    }

    func testARegistrationIsSyncedWhenOnlyTheReinstallAnswerChangedWhileItWasOut() {
        let sent = ApphudIdentity(installationID: "inst-1", anonymousID: "anon-1")
        var current = sent
        current.isReinstall = false

        XCTAssertTrue(ApphudInternal.shouldMarkSynced(done: true, sent: sent, current: current))
        current.anonymousID = "anon-2"
        XCTAssertFalse(ApphudInternal.shouldMarkSynced(done: true, sent: sent, current: current))
    }

    func testSuppliedIDsNoUserIDMeansNoUser() {
        launch(ApphudSuppliedIDs(userID: "Alice", anonymousID: "host-anon", installationID: "host-inst"))

        let identity = launch(ApphudSuppliedIDs(anonymousID: "host-anon-2", installationID: "host-inst")).identity

        XCTAssertNil(identity.userID, "the host has no user: the stored one is not brought back")
        XCTAssertEqual(identity.anonymousID, "host-anon-2")
    }

    // MARK: - Sync and persistence

    func testIdentifyWhoseRequestFailedIsStillSentOnNextLaunch() {
        let store = makeStore()
        var identity = launch().identity
        store.markSynced()
        XCTAssertFalse(store.isSyncPending)

        _ = store.identify("Alice", &identity)

        XCTAssertTrue(makeStore().isSyncPending, "kept until a registration with the new ids succeeds")
        XCTAssertFalse(launch().changed, "the relaunch itself changes nothing")
        XCTAssertTrue(makeStore().isSyncPending, "so registration is not skipped")
    }

    func testSyncPendingSetByResolutionAndLogout() {
        launch()
        XCTAssertTrue(makeStore().isSyncPending, "a new install")
        makeStore().markSynced()

        launch()
        XCTAssertFalse(makeStore().isSyncPending, "an unchanged relaunch")

        var identity = launch().identity
        makeStore().logout(anonymousID: nil, &identity)
        XCTAssertTrue(makeStore().isSyncPending)
    }

    func testStartWithAnotherUserWhileOneIsStoredIsASwitch() {
        launch(ApphudSuppliedIDs(userID: "Alice"))

        XCTAssertTrue(launch(ApphudSuppliedIDs(userID: "Bob")).switchedUser)
        XCTAssertFalse(launch(ApphudSuppliedIDs(userID: "Bob")).switchedUser)
    }

    func testSuppliedAnonymousAndUserIDsSurviveRelaunchInStandaloneMode() {
        launch(ApphudSuppliedIDs(userID: "Alice", anonymousID: "anon-host"))

        let relaunched = launch().identity

        XCTAssertEqual(relaunched.anonymousID, "anon-host")
        XCTAssertEqual(relaunched.userID, "Alice")
    }

    func testReinstallKeyWrittenOnALaterLaunchWhenTheUpgradeLaunchWasLocked() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        keychain.locked = true
        launch()
        XCTAssertNil(keychain.items[.reinstall])

        keychain.locked = false
        launch()

        XCTAssertEqual(Set(keychain.items.keys), [.reinstall, .legacyDeviceID, .legacyUserID])
        XCTAssertEqual(keychain.items[.legacyDeviceID], "OLD-DEVICE")
    }

    func testOldKeychainItemsKeptAfterAReinstallCheckDecidedLater() {
        keychain.items[.legacyDeviceID] = "OLD-DEVICE"
        keychain.locked = true
        launch()

        keychain.locked = false
        let identity = launch().identity

        XCTAssertEqual(identity.isReinstall, false, "decided by the reinstall key alone")
        XCTAssertEqual(Set(keychain.items.keys), [.reinstall, .legacyDeviceID])
        XCTAssertEqual(keychain.items[.legacyDeviceID], "OLD-DEVICE")
    }

    func testNormalLaunchSkipsTheKeychainOnceItIsUpdated() {
        launch()
        let accesses = keychain.accessCount

        launch()

        XCTAssertEqual(keychain.accessCount, accesses, "no Keychain call on a normal launch")
    }

    func testALogoutDropsTheOldDeviceIDBeforeTheNewPersonIsSaved() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")
        var identity = launch().identity
        let before = identity.anonymousID
        var savedAnonymousIDAtTheDrop: String?
        installRecords.onWrite = { [unowned self] in savedAnonymousIDAtTheDrop = defaults.string(forKey: "com.apphud.anonymous_id") }

        makeStore().logout(anonymousID: nil, &identity)

        XCTAssertEqual(savedAnonymousIDAtTheDrop, before, "a crash in between must not leave the old customer to the new person")
    }

    func testAUserSwitchDropsTheOldDeviceIDBeforeTheNewUserIsSaved() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")
        var identity = launch().identity
        var savedUserAtTheDrop: String?
        installRecords.onWrite = { [unowned self] in savedUserAtTheDrop = defaults.string(forKey: "com.apphud.user_id") }

        _ = makeStore().identify("Bob", &identity)

        XCTAssertEqual(savedUserAtTheDrop, "alice@example.com")
    }

    func testAStartWithAnotherUserSavesTheRecordWithoutTheOldDeviceIDBeforeTheUser() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")
        var savedUserAtTheRecord: String?
        installRecords.onWrite = { [unowned self] in savedUserAtTheRecord = defaults.string(forKey: "com.apphud.user_id") }

        let resolution = launch(ApphudSuppliedIDs(userID: "bob"))

        XCTAssertTrue(resolution.switchedUser)
        XCTAssertEqual(savedUserAtTheRecord, "alice@example.com", "a crash in between leaves alice: the next launch drops it again")
        XCTAssertNil(installRecords.record?.legacyDeviceID)
    }

    func testALogoutDropsTheOldDeviceIDInThisProcessWhenTheRecordCannotBeSaved() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")
        var identity = launch().identity
        let store = makeStore()
        installRecords.failWrites = true

        store.logout(anonymousID: nil, &identity)

        XCTAssertNil(store.registrationReport(for: identity).legacyDeviceID)
    }

    func testTheHostsNewAnonymousIDDropsTheOldDeviceIDAsALogout() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")
        launch()

        let supplied = launch(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "OLD-DEVICE"))

        XCTAssertNil(supplied.identity.userID)
        XCTAssertNil(customerParams(supplied.identity)["legacy_device_id"], "the person changed: the old customer is the one before's")
    }

    func testAnUpdateStoppedAfterItsRecordKeepsTheOldGeneratedIDAsTheAnonymousID() {
        // Killed after the record of the update was written and before its ids were saved.
        installRecords.record = ApphudInstallRecord(installationID: "INST", isReinstall: nil, reinstallDecided: true)
        defaults.set("OLD-DEVICE", forKey: "com.apphud.user_id")
        defaults.set("OLD-DEVICE", forKey: "com.apphud.old_device_id")

        let identity = launch().identity

        XCTAssertEqual(identity.anonymousID, "OLD-DEVICE", "the backend still finds the old customer by it")
        XCTAssertNil(identity.userID)
    }

    func testAStartWithAnotherUserDropsTheOldDeviceIDInThisProcessWhenTheRecordCannotBeSaved() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")
        launch()
        let store = makeStore()
        installRecords.failWrites = true

        let resolution = store.resolve(ApphudSuppliedIDs(userID: "bob"))!

        XCTAssertTrue(resolution.switchedUser)
        XCTAssertNil(store.registrationReport(for: resolution.identity).legacyDeviceID)
    }

    func testTheHostsNewAnonymousIDDropsTheOldDeviceIDInThisProcessWhenTheRecordCannotBeSaved() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")
        launch()
        let store = makeStore()
        installRecords.failWrites = true

        let resolution = store.resolve(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "OLD-DEVICE"))!

        XCTAssertNil(store.registrationReport(for: resolution.identity).legacyDeviceID)
    }

    func testVersion2AnonymousThenVersion1ThenVersion2WithAUserIsAFirstIdentifyNotASwitch() {
        let first = launch().identity
        runVersion1(deviceID: first.installationID, userID: first.anonymousID)

        let resolution = launch(ApphudSuppliedIDs(userID: "alice"))

        XCTAssertFalse(resolution.switchedUser, "version 1's user id was version 2's anonymous id")
        XCTAssertEqual(resolution.identity.anonymousID, first.anonymousID)
        XCTAssertEqual(customerParams(resolution.identity)["legacy_device_id"] as? String, first.installationID)
    }

    func testVersion2AnonymousThenVersion1ThenABackupOnVersion2WithAUserIsAFirstIdentify() {
        let first = launch().identity
        runVersion1(deviceID: first.installationID, userID: first.anonymousID)
        restoreBackupOntoAnotherPhone()

        let resolution = launch(ApphudSuppliedIDs(userID: "alice"))

        XCTAssertFalse(resolution.switchedUser, "the record didn't come with the backup: the same rule applies")
        XCTAssertEqual(resolution.identity.anonymousID, first.anonymousID)
    }

    func testAVersion1LogoutKeepsTheOldGeneratedIDFromComingBackAsTheAnonymousID() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        var identity = launch().identity
        _ = makeStore().identify("u", &identity)
        makeStore().logout(anonymousID: nil, &identity)
        runVersion1(deviceID: "V1-DEVICE", userID: identity.anonymousID)
        logOutOnVersion1()
        // Version 1 starts again; the app passes the old generated id back as its user.
        runVersion1(deviceID: "V1-NEW", userID: "OLD-DEVICE", tookOverVersion2: false)

        let next = launch().identity

        XCTAssertNotEqual(next.anonymousID, "OLD-DEVICE", "the anonymous id from before version 1's logout doesn't come back")
        XCTAssertNil(next.userID)
    }

    func testReinstalledOnAnOldSDKVersionItsGeneratedUserIDIsTheAnonymousID() {
        // The old SDK restored its device_id from the Keychain after a reinstall and never saved it back.
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE", inUserDefaults: false)
        defaults.set("OLD-DEVICE", forKey: "com.apphud.user_id")

        let identity = launch().identity

        XCTAssertEqual(identity.anonymousID, "OLD-DEVICE", "the backend finds the old customer by it")
        XCTAssertNil(identity.userID, "a generated id is never a user")
        XCTAssertNotEqual(identity.installationID, "OLD-DEVICE", "never taken from the Keychain")
        let params = customerParams(identity)
        XCTAssertNil(params["user_id"])
        XCTAssertNil(params["legacy_device_id"], "only the device_id in UserDefaults goes as legacy_device_id")
        XCTAssertEqual(makeStore().idsForVersion1()?.deviceID, "OLD-DEVICE", "version 1 comes back to its device id")
    }

    func testReinstalledOnAnOldSDKVersionARealUserStaysTheUser() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com", inUserDefaults: false)
        defaults.set("alice@example.com", forKey: "com.apphud.user_id")

        let identity = launch().identity

        XCTAssertEqual(identity.userID, "alice@example.com")
        XCTAssertNotEqual(identity.anonymousID, "alice@example.com")
    }

    func testReinstalledOnAnOldSDKVersionWithTheKeychainLockedKeepsTheStoredUser() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE", inUserDefaults: false)
        defaults.set("OLD-DEVICE", forKey: "com.apphud.user_id")
        keychain.locked = true

        let identity = launch().identity

        XCTAssertEqual(identity.userID, "OLD-DEVICE", "nothing to compare with: kept as it was stored")
    }

    func testUpgradeFromStartManuallyHostIsAnUpgrade() {
        // startManually(deviceID:) never stored device_id; the SDK stored a user_id.
        defaults.set("GENERATED-USER", forKey: "com.apphud.user_id")

        let resolution = launch(ApphudSuppliedIDs(installationID: "HOST-DEVICE"))

        XCTAssertEqual(resolution.launch, .upgrade)
        XCTAssertNil(resolution.identity.isReinstall)
        XCTAssertEqual(resolution.identity.installationID, "HOST-DEVICE")
    }

    func testDamagedRecordStartsANewInstallWithoutAReinstallVerdict() {
        launch()
        installRecords.damaged = true

        let identity = launch().identity

        XCTAssertNil(identity.isReinstall, "our own key is there: no verdict")
    }

    func testKeptLegacyDeviceIDIsNoUpdateOnALaterLaunch() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        let updated = launch().identity
        makeStore().markRegistered(reinstallSent: false, legacyDeviceIDSent: true)

        let resolution = launch()

        XCTAssertEqual(resolution.launch, .normal)
        XCTAssertFalse(resolution.changed)
        XCTAssertEqual(resolution.identity, updated)
        XCTAssertNil(customerParams(resolution.identity)["legacy_device_id"], "sent once")
        XCTAssertEqual(defaults.string(forKey: "com.apphud.device_id"), "OLD-DEVICE")
    }

    // MARK: - Identity version switch

    /// What identity version 1 leaves behind when it runs with these ids: UserDefaults, the Keychain items, the marker.
    /// `tookOverVersion2`: its first start after version 2; false for a start after its own logout.
    private func runVersion1(deviceID: String, userID: String, tookOverVersion2: Bool = true) {
        defaults.set(deviceID, forKey: "com.apphud.device_id")
        defaults.set(userID, forKey: "com.apphud.user_id")
        keychain.items[.legacyDeviceID] = deviceID
        keychain.items[.legacyUserID] = userID
        makeStore().markVersion1(tookOverVersion2: tookOverVersion2)
    }

    func testVersion1AfterAFreshVersion2InstallSendsTheInstallationAndAnonymousIDs() {
        let identity = launch().identity

        let ids = makeStore().idsForVersion1()

        XCTAssertEqual(ids?.deviceID, identity.installationID)
        XCTAssertEqual(ids?.userID, identity.anonymousID)
    }

    func testVersion1AfterVersion2SendsTheUserTheAppSet() {
        var identity = launch().identity
        _ = makeStore().identify("alice", &identity)

        XCTAssertEqual(makeStore().idsForVersion1()?.deviceID, identity.installationID)
        XCTAssertEqual(makeStore().idsForVersion1()?.userID, "alice")
    }

    func testVersion1AfterAVersion2LogoutSendsTheNewAnonymousID() {
        var identity = launch().identity
        _ = makeStore().identify("alice", &identity)
        makeStore().logout(anonymousID: nil, &identity)

        XCTAssertEqual(makeStore().idsForVersion1()?.userID, identity.anonymousID)
    }

    func testVersion1AfterAnUpdatedInstallSendsTheOldIDs() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        launch()

        let ids = makeStore().idsForVersion1()

        XCTAssertEqual(ids?.deviceID, "OLD-DEVICE")
        XCTAssertEqual(ids?.userID, "OLD-DEVICE")
    }

    func testVersion1AfterAnUpdatedInstallWithAUserSendsTheOldDeviceIDAndTheUser() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")
        launch()

        let ids = makeStore().idsForVersion1()

        XCTAssertEqual(ids?.deviceID, "OLD-DEVICE")
        XCTAssertEqual(ids?.userID, "alice@example.com")
    }

    func testVersion1AfterSuppliedVersion2IDsSendsThem() {
        makeStore().markVersion1()
        launch(ApphudSuppliedIDs(userID: "host-user", anonymousID: "host-anon", installationID: "host-install", isReinstall: false))

        let ids = makeStore().idsForVersion1()

        XCTAssertEqual(ids?.deviceID, "host-install")
        XCTAssertEqual(ids?.userID, "host-user")
    }

    func testVersion1AfterABuildWithoutTheMarkerSendsTheVersion2IDs() {
        let identity = launch().identity
        defaults.removeObject(forKey: ApphudIdentityStore.identityVersionKey)

        XCTAssertEqual(makeStore().idsForVersion1()?.deviceID, identity.installationID)
    }

    func testVersion1TakesTheIDsOverOnlyOnItsFirstLaunchAfterVersion2() {
        XCTAssertNil(makeStore().idsForVersion1(), "a fresh install")
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        XCTAssertNil(makeStore().idsForVersion1(), "only an old version ran")
        makeStore().markVersion1()
        XCTAssertNil(makeStore().idsForVersion1(), "only version 1 ran")

        launch()
        makeStore().markVersion1()

        XCTAssertNil(makeStore().idsForVersion1(), "version 1 already runs on its own ids")
    }

    func testVersion2AfterVersion1TakesItsIDsOverAgain() {
        let first = launch().identity
        makeStore().markSynced()
        runVersion1(deviceID: first.installationID, userID: first.anonymousID)

        let resolution = launch()

        XCTAssertEqual(resolution.launch, .upgrade)
        XCTAssertTrue(resolution.changed, "registers again")
        XCTAssertTrue(makeStore().isSyncPending)
        XCTAssertEqual(resolution.identity.installationID, first.installationID, "the installation stays")
        XCTAssertEqual(resolution.identity.anonymousID, first.anonymousID)
        XCTAssertNil(resolution.identity.userID, "the anonymous id version 1 sent as user_id is no user")
        XCTAssertEqual(customerParams(resolution.identity)["legacy_device_id"] as? String, first.installationID)
        XCTAssertEqual(defaults.string(forKey: ApphudIdentityStore.identityVersionKey), "v2")
    }

    func testVersion2AfterAVersion1LogoutTakesTheNewIDsOver() {
        let first = launch().identity
        runVersion1(deviceID: first.installationID, userID: first.anonymousID)
        // A logout in version 1 and a new start make new ids.
        makeStore().markVersion1LoggedOut()
        runVersion1(deviceID: "V1-NEW", userID: "V1-NEW", tookOverVersion2: false)

        let identity = launch().identity

        XCTAssertEqual(identity.installationID, first.installationID, "the installation stays")
        XCTAssertEqual(identity.anonymousID, "V1-NEW")
        XCTAssertNil(identity.userID)
        XCTAssertEqual(customerParams(identity)["legacy_device_id"] as? String, "V1-NEW")
    }

    func testVersion2AfterAVersion1LogoutIsANewPerson() {
        var first = launch().identity
        _ = makeStore().identify("alice", &first)
        runVersion1(deviceID: first.installationID, userID: "alice")
        // Logout in version 1 removes its ids; no version 1 start made new ones.
        makeStore().markVersion1LoggedOut()
        defaults.removeObject(forKey: "com.apphud.device_id")
        defaults.removeObject(forKey: "com.apphud.user_id")
        keychain.items[.legacyDeviceID] = nil
        keychain.items[.legacyUserID] = nil

        let identity = launch().identity

        XCTAssertEqual(identity.installationID, first.installationID, "the installation stays")
        XCTAssertNotEqual(identity.anonymousID, first.anonymousID, "the person before the logout is gone")
        XCTAssertNil(identity.userID)
        XCTAssertNil(customerParams(identity)["legacy_device_id"])
    }

    func testVersion2AfterAVersion1LogoutAndAnotherUserTakesNoAnonymousIDFromBefore() {
        var first = launch().identity
        _ = makeStore().identify("alice", &first)
        runVersion1(deviceID: first.installationID, userID: "alice")
        // Logout in version 1, a new start, and another user.
        makeStore().markVersion1LoggedOut()
        runVersion1(deviceID: "V1-NEW", userID: "bob", tookOverVersion2: false)

        let identity = launch().identity

        XCTAssertEqual(identity.userID, "bob")
        XCTAssertNotEqual(identity.anonymousID, first.anonymousID, "alice's anonymous id stays with alice")
        XCTAssertEqual(customerParams(identity)["legacy_device_id"] as? String, "V1-NEW")
    }

    func testVersion2LogoutResetsTheIDsOfVersion1() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")
        var identity = launch().identity

        makeStore().logout(anonymousID: nil, &identity)

        XCTAssertNil(defaults.string(forKey: "com.apphud.device_id"))
        // Blanked, as version 1's own logout does: version 1 reads "" as no id.
        XCTAssertEqual(keychain.items[.legacyDeviceID], "")
        XCTAssertEqual(keychain.items[.legacyUserID], "")
        XCTAssertNotNil(keychain.items[.reinstall], "the reinstall key stays")
        let ids = makeStore().idsForVersion1()
        XCTAssertNotNil(ids?.deviceID, "a new device id for version 1")
        XCTAssertNotEqual(ids?.deviceID, "OLD-DEVICE", "never the logged-out person's")
        XCTAssertNotEqual(ids?.deviceID, identity.installationID)
        XCTAssertEqual(ids?.userID, identity.anonymousID)
    }

    func testVersion1AfterAVersion2LogoutKeepsItsNewDeviceIDOnTheNextSwitch() {
        var identity = launch().identity
        makeStore().logout(anonymousID: nil, &identity)
        // Version 1 makes a new device id for the new anonymous person.
        runVersion1(deviceID: "V1-NEW", userID: identity.anonymousID)

        let next = launch().identity

        XCTAssertEqual(next.anonymousID, identity.anonymousID, "the same person")
        XCTAssertEqual(makeStore().idsForVersion1()?.deviceID, "V1-NEW")
    }

    func testOwnVersion1KeychainItemsTellNoReinstallToALaterCheck() {
        keychain.locked = true
        let first = launch().identity
        XCTAssertNil(first.isReinstall)
        keychain.locked = false
        runVersion1(deviceID: first.installationID, userID: first.anonymousID)
        launch()

        let identity = launch().identity

        XCTAssertEqual(identity.isReinstall, false, "version 1 wrote those items on this install")
    }

    func testVersion2AfterVersion1WithTheAppsOwnDeviceIDKeepsItsUser() {
        var first = launch().identity
        makeStore().logout(anonymousID: nil, &first)
        // startManually(deviceID:) on version 1 keeps no device id of its own; the server named the user.
        defaults.set("bob", forKey: "com.apphud.user_id")
        makeStore().markVersion1(tookOverVersion2: true)

        let identity = launch().identity

        XCTAssertEqual(identity.userID, "bob")
        XCTAssertEqual(identity.anonymousID, first.anonymousID, "no logout on version 1: the same person")
        XCTAssertNil(customerParams(identity)["legacy_device_id"])
    }

    func testVersion1LogoutThenVersion2ThenVersion1MakesANewDeviceID() {
        var first = launch().identity
        _ = makeStore().identify("alice", &first)
        runVersion1(deviceID: first.installationID, userID: "alice")
        // Logout on version 1, then version 2 without a version 1 start in between.
        makeStore().markVersion1LoggedOut()
        defaults.removeObject(forKey: "com.apphud.device_id")
        defaults.removeObject(forKey: "com.apphud.user_id")
        let second = launch().identity

        let ids = makeStore().idsForVersion1()

        XCTAssertEqual(ids?.userID, second.anonymousID)
        XCTAssertNotNil(ids?.deviceID)
        XCTAssertNotEqual(ids?.deviceID, first.installationID, "alice's device id stays with alice")
    }

    func testVersion2LogoutBlanksTheOldKeychainItemsWhileTheReinstallCheckIsUndecided() {
        keychain.items[.legacyDeviceID] = "OLD-DEVICE"
        keychain.locked = true
        var identity = launch().identity
        keychain.locked = false

        makeStore().logout(anonymousID: nil, &identity)

        XCTAssertEqual(keychain.items[.legacyDeviceID], "")
        XCTAssertNil(keychain.items[.reinstall])
        XCTAssertEqual(launch().identity.isReinstall, false, "the reinstall key decides, not the old items")
    }

    func testVersion2LogoutBlanksTheOldKeychainItemsWhenTheAppSuppliesTheIDs() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")
        var identity = launch(ApphudSuppliedIDs(userID: "alice@example.com", anonymousID: "host-anon",
                                                installationID: "host-install", isReinstall: false)).identity
        XCTAssertNil(installRecords.record?.keychainUpdated, "supplied ids never write the reinstall key")

        makeStore().logout(anonymousID: "host-anon-2", &identity)

        XCTAssertEqual(keychain.items[.legacyDeviceID], "", "version 1 after a reinstall never gets the old id back")
        XCTAssertEqual(keychain.items[.legacyUserID], "")
    }

    func testVersion2LogoutAddsNoKeychainItemsOfVersion1() {
        var identity = launch().identity

        makeStore().logout(anonymousID: nil, &identity)

        XCTAssertEqual(Set(keychain.items.keys), [.reinstall])
    }

    func testAVersion1LogoutThatVersion1StartedAgainAfterLeavesNoFlagForALaterLaunch() {
        // Version 1 only: a logout, then a start with its own new ids.
        makeStore().markVersion1()
        makeStore().markVersion1LoggedOut()
        defaults.set("", forKey: "com.apphud.device_id")
        defaults.set("", forKey: "com.apphud.user_id")
        runVersion1(deviceID: "G", userID: "G", tookOverVersion2: false)
        // Version 2, and the record can't be saved.
        installRecords.failWrites = true
        var identity = launch().identity
        XCTAssertEqual(identity.anonymousID, "G", "the person version 1 started after its logout")
        makeStore().logout(anonymousID: nil, &identity)

        let next = launch().identity

        XCTAssertEqual(next.anonymousID, identity.anonymousID, "the person after the logout on version 2 stays")
    }

    func testTheRollbackRegistrationStaysPendingUntilOneSucceeds() {
        let identity = launch().identity
        runVersion1(deviceID: identity.installationID, userID: identity.anonymousID)
        XCTAssertTrue(makeStore().isVersion1RegistrationPending)

        makeStore().markVersion1()
        XCTAssertTrue(makeStore().isVersion1RegistrationPending, "a later launch still registers")

        makeStore().markVersion1Registered()
        XCTAssertFalse(makeStore().isVersion1RegistrationPending)
    }

    func testTheRollbackRegistrationFlagIsReadFromUserDefaultsOncePerStore() throws {
        let suiteName = "ApphudIdentityTests.\(UUID().uuidString)"
        suiteNames.append(suiteName)
        let counting = try XCTUnwrap(CountingDefaults(suiteName: suiteName))
        counting.set(true, forKey: ApphudIdentityStore.version1RegistrationPendingKey)
        let store = ApphudIdentityStore(defaults: counting, keychain: keychain, installRecords: installRecords) { UUID().uuidString }

        for _ in 0..<100 { XCTAssertTrue(store.isVersion1RegistrationPending) }

        // Requests check it every time they go: a read of UserDefaults there delays them past SDK 4.6.
        XCTAssertEqual(counting.pendingReads, 1)
        store.markVersion1Registered()
        XCTAssertFalse(store.isVersion1RegistrationPending)
        XCTAssertNil(counting.object(forKey: ApphudIdentityStore.version1RegistrationPendingKey))
        store.markVersion1(tookOverVersion2: true)
        XCTAssertTrue(store.isVersion1RegistrationPending)
        XCTAssertTrue(counting.bool(forKey: ApphudIdentityStore.version1RegistrationPendingKey))
    }

    func testARegistrationOfVersion1WithNothingPendingWritesNothing() throws {
        let suiteName = "ApphudIdentityTests.\(UUID().uuidString)"
        suiteNames.append(suiteName)
        let counting = try XCTUnwrap(CountingDefaults(suiteName: suiteName))
        let store = ApphudIdentityStore(defaults: counting, keychain: keychain, installRecords: installRecords) { UUID().uuidString }

        store.markVersion1Registered()
        store.markVersion1Registered()

        // Every registration of version 1 clears the flag; SDK 4.6 wrote nothing to UserDefaults there.
        XCTAssertEqual(counting.pendingWrites, 0)
    }

    func testABackupOfIDsVersion1UsedLastAfterItsLogoutBringsItsPerson() {
        var first = launch().identity
        _ = makeStore().identify("alice", &first)
        runVersion1(deviceID: first.installationID, userID: "alice")
        makeStore().markVersion1LoggedOut()
        runVersion1(deviceID: "V1-NEW", userID: "bob", tookOverVersion2: false)
        restoreBackupOntoAnotherPhone()

        let resolution = launch()

        XCTAssertEqual(resolution.launch, .upgrade)
        XCTAssertEqual(resolution.identity.userID, "bob")
        XCTAssertNotEqual(resolution.identity.anonymousID, first.anonymousID, "alice's anonymous id stays with alice")
    }

    /// What the logout of version 1 (as in 4.6.1) leaves: empty ids in UserDefaults and the Keychain.
    private func logOutOnVersion1() {
        makeStore().markVersion1LoggedOut()
        defaults.set("", forKey: "com.apphud.device_id")
        defaults.set("", forKey: "com.apphud.user_id")
        keychain.items[.legacyDeviceID] = ""
        keychain.items[.legacyUserID] = ""
    }

    func testALogoutOfVersion1BeforeTheFirstStartIsNoReinstall() {
        // A logout before any start runs version 1's logout on a fresh install.
        logOutOnVersion1()

        XCTAssertEqual(launch().identity.isReinstall, false, "this install's own logout left the empty items")
    }

    func testABackupTakenAfterAVersion1LogoutBringsNoPersonBack() {
        var first = launch().identity
        _ = makeStore().identify("alice", &first)
        runVersion1(deviceID: first.installationID, userID: "alice")
        logOutOnVersion1()
        restoreBackupOntoAnotherPhone()

        let identity = launch().identity

        XCTAssertNotEqual(identity.anonymousID, first.anonymousID)
        XCTAssertNil(identity.userID)
        XCTAssertNotNil(makeStore().idsForVersion1()?.deviceID)
        XCTAssertNotEqual(makeStore().idsForVersion1()?.deviceID, first.installationID)
    }

    func testAPersonAfterAVersion1LogoutStaysWhenTheRecordCannotBeSaved() {
        var first = launch().identity
        _ = makeStore().identify("alice", &first)
        runVersion1(deviceID: first.installationID, userID: "alice")
        logOutOnVersion1()
        installRecords.failWrites = true

        let once = launch().identity
        let again = launch().identity

        XCTAssertNotEqual(once.anonymousID, first.anonymousID)
        XCTAssertEqual(again.anonymousID, once.anonymousID, "no new person on every launch")
    }

    func testTheVersionThatRanLastIsKnownBeforeAStart() {
        XCTAssertNil(makeStore().lastIdentityVersion)
        makeStore().markVersion1()
        XCTAssertEqual(makeStore().lastIdentityVersion, .v1)
        launch()
        XCTAssertEqual(makeStore().lastIdentityVersion, .v2)
        defaults.removeObject(forKey: ApphudIdentityStore.identityVersionKey)
        XCTAssertEqual(makeStore().lastIdentityVersion, .v2, "ids of version 2 without a marker")
    }

    func testABackupAfterAVersion1LogoutKeepsTheUserVersion1StartedWith() {
        let first = launch().identity
        runVersion1(deviceID: first.installationID, userID: first.anonymousID)
        logOutOnVersion1()
        // startManually(userID: "bob", deviceID:) on version 1 saves no device id of the app's own.
        defaults.set("bob", forKey: "com.apphud.user_id")
        restoreBackupOntoAnotherPhone()

        let identity = launch().identity

        XCTAssertEqual(identity.userID, "bob")
        XCTAssertNotEqual(identity.anonymousID, first.anonymousID)
    }

    func testADamagedRecordAfterAVersion1LogoutBringsNoPersonBack() {
        var first = launch().identity
        _ = makeStore().identify("alice", &first)
        runVersion1(deviceID: first.installationID, userID: "alice")
        logOutOnVersion1()
        installRecords.damaged = true

        let identity = launch().identity

        XCTAssertNotEqual(identity.anonymousID, first.anonymousID)
        XCTAssertNil(identity.userID)
    }

    func testAVersion2LogoutWhileTheMarkerStillSaysVersion1GivesVersion1ANewDeviceID() {
        let first = launch().identity
        runVersion1(deviceID: first.installationID, userID: first.anonymousID)
        installRecords.failWrites = true
        var identity = launch().identity
        XCTAssertEqual(makeStore().lastIdentityVersion, .v1, "the record wasn't saved")

        makeStore().logout(anonymousID: nil, &identity)
        let ids = makeStore().idsForVersion1()

        XCTAssertEqual(ids?.userID, identity.anonymousID)
        XCTAssertNotNil(ids?.deviceID)
        XCTAssertNotEqual(ids?.deviceID, first.installationID)
    }

    func testVersion2AfterVersion1KeepsTheUserVersion1Set() {
        let first = launch().identity
        runVersion1(deviceID: first.installationID, userID: "alice")
        makeStore().markSynced()

        let resolution = launch()
        let identity = resolution.identity

        XCTAssertTrue(resolution.changed, "only legacy_device_id is new, and it must be registered")
        XCTAssertTrue(makeStore().isSyncPending)
        XCTAssertEqual(identity.anonymousID, first.anonymousID)
        XCTAssertEqual(identity.userID, "alice")
        XCTAssertEqual(customerParams(identity)["user_id"] as? String, "alice")
        XCTAssertEqual(customerParams(identity)["legacy_device_id"] as? String, first.installationID)
    }

    func testOldVersionThenVersion2ThenVersion1ThenVersion2KeepsTheIDs() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        let updated = launch().identity
        makeStore().markRegistered(reinstallSent: false, legacyDeviceIDSent: true)
        guard let ids = makeStore().idsForVersion1(), let deviceID = ids.deviceID else { return XCTFail("no ids for version 1") }
        XCTAssertEqual(deviceID, "OLD-DEVICE")
        XCTAssertEqual(ids.userID, "OLD-DEVICE")
        runVersion1(deviceID: deviceID, userID: ids.userID)

        let again = launch()

        XCTAssertEqual(again.launch, .upgrade)
        XCTAssertEqual(again.identity, updated)
        XCTAssertEqual(customerParams(again.identity)["legacy_device_id"] as? String, "OLD-DEVICE")
        XCTAssertEqual(makeStore().idsForVersion1()?.deviceID, "OLD-DEVICE")
        XCTAssertEqual(makeStore().idsForVersion1()?.userID, "OLD-DEVICE")
    }

    func testVersion1AfterVersion2SendsTheDeviceIDVersion1MadeLast() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        launch()
        runVersion1(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        // A logout in version 1 and a new start make new ids.
        makeStore().markVersion1LoggedOut()
        runVersion1(deviceID: "V1-NEW", userID: "V1-NEW", tookOverVersion2: false)
        launch()

        let ids = makeStore().idsForVersion1()

        XCTAssertEqual(ids?.deviceID, "V1-NEW")
        XCTAssertEqual(ids?.userID, "V1-NEW")
    }

    func testASwitchFromVersion1ThatCouldNotBeSavedRunsAgain() {
        let first = launch().identity
        runVersion1(deviceID: first.installationID, userID: first.anonymousID)
        installRecords.failWrites = true
        XCTAssertEqual(launch().launch, .upgrade)

        installRecords.failWrites = false

        XCTAssertEqual(launch().launch, .upgrade, "the marker waits for the saved record")
        XCTAssertEqual(launch().launch, .normal)
    }

    func testAVersion1LaunchIsNoReinstallForVersion2() {
        let first = launch().identity
        runVersion1(deviceID: first.installationID, userID: first.anonymousID)

        let identity = launch().identity

        XCTAssertEqual(identity.isReinstall, false)
        XCTAssertNil(customerParams(identity)["reinstall"])
    }

    // MARK: - Installation record file

    func testRecordFileIsExcludedFromBackupAfterEveryWrite() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ApphudIdentityTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = ApphudInstallRecordFile(directory: directory)
        XCTAssertEqual(file.read(), .missing)

        let record = ApphudInstallRecord(installationID: "inst-1", isReinstall: false, reinstallDecided: true)
        XCTAssertTrue(file.write(record))
        XCTAssertTrue(file.write(record), "an atomic write replaces the file")

        XCTAssertEqual(file.read(), .found(record))
        XCTAssertEqual(try file.fileURL.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
        XCTAssertEqual(try directory.resourceValues(forKeys: [.isExcludedFromBackupKey]).isExcludedFromBackup, true)
    }

    func testRecordFileKeepsWhatRegistrationsReported_AndReadsARecordWrittenBeforeIt() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ApphudIdentityTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        let file = ApphudInstallRecordFile(directory: directory)

        var record = ApphudInstallRecord(installationID: "inst-1", isReinstall: true, reinstallDecided: true, legacyDeviceID: "OLD-DEVICE")
        record.reinstallReported = true
        XCTAssertTrue(file.write(record))
        XCTAssertEqual(file.read(), .found(record))

        try Data(#"{"installationID":"inst-2","isReinstall":true,"reinstallDecided":true,"keychainUpdated":true}"#.utf8).write(to: file.fileURL)
        var before = ApphudInstallRecord(installationID: "inst-2", isReinstall: true, reinstallDecided: true)
        before.keychainUpdated = true
        XCTAssertEqual(file.read(), .found(before), "a record saved by the previous build: nothing reported yet")
    }

    func testRecordFileDamagedOrUnreadable() throws {
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ApphudIdentityTests-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: directory) }
        var file = ApphudInstallRecordFile(directory: directory)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: file.fileURL)

        XCTAssertEqual(file.read(), .damaged)

        try FileManager.default.removeItem(at: file.fileURL)
        try FileManager.default.createDirectory(at: file.fileURL, withIntermediateDirectories: true)  // exists, can't be read as data
        #if os(macOS)
        // macOS reports a directory read as EISDIR, not a permission error. iOS reports it as a
        // permission error, which counts as data protection there: this case is macOS-only.
        XCTAssertEqual(file.read(), .damaged, "a read error with protected data available")
        #else
        XCTAssertEqual(file.read(), .unreadable, "a permission error counts as data protection")
        #endif
        file.protectedDataAvailable = { false }
        XCTAssertEqual(file.read(), .unreadable, "before the first unlock: wait, never mint over it")
    }

    // MARK: - Identify wiring

    @MainActor
    func testApplyIdentifyCallsTheDelegateOnceAndMarksPending() {
        let sdk = ApphudInternal.shared
        let savedIdentity = sdk.identity
        let savedStore = sdk.identityStore
        let savedDelegate = sdk.delegate
        defer {
            sdk.identity = savedIdentity
            sdk.identityStore = savedStore
            sdk.delegate = savedDelegate
        }
        sdk.identityStore = makeStore()
        sdk.identity = launch().identity
        sdk.identityStore.markSynced()
        let delegate = RecordingDelegate()
        sdk.delegate = delegate

        XCTAssertTrue(sdk.applyIdentify(userID: "Alice"))
        XCTAssertFalse(sdk.applyIdentify(userID: "Alice"), "the same id is a no-op")

        XCTAssertEqual(delegate.userIDs, ["Alice"])
        XCTAssertEqual(sdk.identifiedUserID, "Alice")
        XCTAssertEqual(sdk.currentUserID, "Alice")
        XCTAssertTrue(sdk.identityStore.isSyncPending)
    }

    // MARK: - Read errors, launch flags, sync

    func testPermissionErrorMeansUnreadableNotDamaged() {
        let noPermission = NSError(domain: NSCocoaErrorDomain, code: NSFileReadNoPermissionError)
        let posixEPERM = NSError(domain: NSCocoaErrorDomain, code: NSFileReadUnknownError,
                                 userInfo: [NSUnderlyingErrorKey: NSError(domain: NSPOSIXErrorDomain, code: Int(EPERM))])
        let isADirectory = NSError(domain: NSPOSIXErrorDomain, code: Int(EISDIR))

        XCTAssertTrue(ApphudInstallRecordFile.isPermissionError(noPermission))
        XCTAssertTrue(ApphudInstallRecordFile.isPermissionError(posixEPERM))
        XCTAssertTrue(ApphudInstallRecordFile.isPermissionError(NSError(domain: NSPOSIXErrorDomain, code: Int(EACCES))))
        XCTAssertFalse(ApphudInstallRecordFile.isPermissionError(isADirectory))
    }

    func testUpgradeWithSDKGeneratedUserThenStartWithUserIsNotASwitch() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")

        let resolution = launch(ApphudSuppliedIDs(userID: "Alice"))

        XCTAssertFalse(resolution.switchedUser, "the old SDK-generated id was never a user")
        XCTAssertEqual(resolution.identity.userID, "Alice")
        XCTAssertEqual(resolution.identity.anonymousID, "OLD-DEVICE")
    }

    func testLaunchFlagsOnlyForTheInstallsFirstLaunch() {
        func flags(_ launch: ApphudLaunchKind, _ isReinstall: Bool?) -> (Bool, Bool) {
            let identity = ApphudIdentity(installationID: "i", anonymousID: "a", isReinstall: isReinstall)
            let result = ApphudInternal.launchFlags(ApphudIdentityResolution(identity: identity, launch: launch, changed: false))
            return (result.isFreshInstall, result.isRedownload)
        }
        XCTAssertTrue(flags(.newInstall, true) == (true, true))
        XCTAssertTrue(flags(.newInstall, false) == (true, false))
        XCTAssertTrue(flags(.normal, true) == (false, false), "a reinstall's later launches send no first-launch metrics")
        XCTAssertTrue(flags(.upgrade, nil) == (false, false))
    }

    func testMarkSyncedOnlyForASuccessfulRequestWithCurrentIDs() {
        let sent = ApphudIdentity(installationID: "i", anonymousID: "a")
        var identified = sent
        identified.userID = "Alice"

        XCTAssertTrue(ApphudInternal.shouldMarkSynced(done: true, sent: sent, current: sent))
        XCTAssertFalse(ApphudInternal.shouldMarkSynced(done: false, sent: sent, current: sent))
        XCTAssertFalse(ApphudInternal.shouldMarkSynced(done: true, sent: sent, current: identified),
                       "an identify while the request was out is still unsent")
    }

    func testQueryValueEscapesSeparators() {
        let escaped = "a&b=c+d?e#f".addingPercentEncoding(withAllowedCharacters: .apphudQueryValueAllowed) ?? ""

        XCTAssertEqual(escaped, "a%26b%3Dc%2Bd%3Fe%23f")
    }

    // MARK: - Logout, crash safety, escaping

    func testRealPermissionErrorIsRecognised() throws {
        try XCTSkipIf(getuid() == 0, "root reads a chmod-000 file")
        let directory = FileManager.default.temporaryDirectory.appendingPathComponent("ApphudIdentityTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let url = directory.appendingPathComponent("locked.json")
        try Data("{}".utf8).write(to: url)
        try FileManager.default.setAttributes([.posixPermissions: 0o000], ofItemAtPath: url.path)
        defer {
            try? FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: url.path)
            try? FileManager.default.removeItem(at: directory)
        }

        XCTAssertThrowsError(try Data(contentsOf: url)) { error in
            XCTAssertTrue(ApphudInstallRecordFile.isPermissionError(error), "\(error)")
        }
    }

    @MainActor
    func testLogoutKeepsInstallationRotatesAnonymousClearsUserInOneStep() async {
        let sdk = ApphudInternal.shared
        let savedIdentity = sdk.identity
        let savedStore = sdk.identityStore
        let savedSession = ApphudSession.shared
        defer {
            sdk.identity = savedIdentity
            sdk.identityStore = savedStore
            ApphudSession.shared = savedSession
        }
        ApphudSession.shared = ApphudSession(defaults: defaults, notificationCenter: NotificationCenter(), canPersist: { true })
        sdk.identityStore = makeStore()
        var identity = ApphudIdentity(installationID: "inst-1", anonymousID: "anon-1", isReinstall: true)
        _ = sdk.identityStore.identify("Alice", &identity)
        sdk.identity = identity
        sdk.identityStore.markSynced()
        sdk.currentUser = ApphudUser(userID: "Alice")
        XCTAssertEqual(defaults.string(forKey: "com.apphud.user_id"), "Alice", "precondition: Alice is saved")

        let logout = Task { await sdk.logout(anonymousID: "anon-2") }
        // Nothing on the main actor may see the new ids saved but the old ones still in use.
        var savedButNotSwitched = false
        var spins = 0
        while sdk.currentAnonymousID != "anon-2" && spins < 100_000 {
            if defaults.string(forKey: "com.apphud.anonymous_id") == "anon-2" { savedButNotSwitched = true }
            spins += 1
            await Task.yield()
        }
        XCTAssertNil(sdk.currentUser, "the previous customer goes in the same step as the ids")
        await logout.value

        XCTAssertFalse(savedButNotSwitched, "the ids are saved and switched in one step")
        XCTAssertEqual(sdk.currentInstallationID, "inst-1")
        XCTAssertEqual(sdk.currentAnonymousID, "anon-2")
        XCTAssertNil(sdk.identifiedUserID)
        XCTAssertEqual(sdk.isReinstall, true, "the installation's reinstall verdict stays")
        XCTAssertNil(sdk.currentUser)
        XCTAssertEqual(defaults.string(forKey: "com.apphud.anonymous_id"), "anon-2")
        XCTAssertNil(defaults.string(forKey: "com.apphud.user_id"))
        XCTAssertTrue(sdk.identityStore.isSyncPending)
    }

    func testAnonymousIDIsNeverTheUser() {
        // A host that kept its old `Apphud.userID()`, the SDK-generated id, passes it to start.
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        var identity = launch(ApphudSuppliedIDs(userID: "OLD-DEVICE")).identity

        XCTAssertNil(identity.userID)
        XCTAssertEqual(identity.anonymousID, "OLD-DEVICE")
        XCTAssertNil(customerParams(identity)["user_id"])
        XCTAssertNil(launch().identity.userID, "nor stored as one")

        // `updateUserID(Apphud.userID())` while anonymous.
        XCTAssertEqual(makeStore().identify("OLD-DEVICE", &identity), .unchanged)
        XCTAssertNil(identity.userID)

        // Once identified, a start with the anonymous id keeps the user: only logout clears it.
        XCTAssertEqual(makeStore().identify("Alice", &identity), .identified)
        XCTAssertEqual(launch(ApphudSuppliedIDs(userID: "OLD-DEVICE")).identity.userID, "Alice")

        // Every id supplied by the app, its anonymous id passed as its user id too.
        let allSupplied = launch(ApphudSuppliedIDs(userID: "host-anon", anonymousID: "host-anon", installationID: "host-inst")).identity
        XCTAssertNil(allSupplied.userID)
    }

    func testUpgradeKilledDuringTheKeychainCleanupKeepsTheGeneratedUserIDAnonymous() throws {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        var onDisk: (defaults: [String: Any], record: ApphudInstallRecord?)?
        keychain.onAccess = { [unowned self] in
            if onDisk == nil { onDisk = (self.defaults.dictionaryRepresentation(), self.installRecords.record) }
        }
        launch()
        keychain.onAccess = nil

        // The process is killed at the first Keychain call of the upgrade launch.
        let killed = try XCTUnwrap(onDisk)
        installApp()
        killed.defaults.forEach { defaults.set($0.value, forKey: $0.key) }
        installRecords.record = killed.record
        let identity = launch().identity

        XCTAssertNil(identity.userID, "an SDK-generated id never becomes a user")
        XCTAssertEqual(identity.anonymousID, "OLD-DEVICE")
        XCTAssertEqual(identity.installationID, "OLD-DEVICE")
        XCTAssertTrue(makeStore().isSyncPending, "the adoption request is still sent")
    }

    func testStartManuallyHostUpgradeKilledBeforeTheRecordIsStillAnUpgrade() throws {
        // startManually(deviceID:) never stored device_id; the SDK stored a user_id. The old
        // Keychain item is there too.
        defaults.set("GENERATED-USER", forKey: "com.apphud.user_id")
        keychain.items[.legacyDeviceID] = "HOST-DEVICE"
        var onDisk: [String: Any]?
        installRecords.onWrite = { [unowned self] in
            if onDisk == nil { onDisk = self.defaults.dictionaryRepresentation() }
        }
        launch(ApphudSuppliedIDs(installationID: "HOST-DEVICE"))
        installRecords.onWrite = nil

        // The process is killed right before the installation record is first written.
        let killed = try XCTUnwrap(onDisk)
        installApp()
        killed.forEach { defaults.set($0.value, forKey: $0.key) }
        let resolution = launch(ApphudSuppliedIDs(installationID: "HOST-DEVICE"))

        XCTAssertEqual(resolution.launch, .upgrade)
        XCTAssertNil(resolution.identity.isReinstall, "an install updated in place is no reinstall")
    }

    @MainActor
    func testPreviewScreenURLEscapesIDs() throws {
        let saved = ApphudInternal.shared.identity
        defer { ApphudInternal.shared.identity = saved }
        ApphudInternal.shared.identity = ApphudIdentity(installationID: "a&b=c", anonymousID: "d+e#f")

        let url = try XCTUnwrap(ApphudHttpClient.shared.makeScreenRequest(screenID: "screen")?.url?.absoluteString)

        XCTAssertTrue(url.contains("installation_id=a%26b%3Dc"), url)
        XCTAssertTrue(url.contains("anonymous_id=d%2Be%23f"), url)
        XCTAssertFalse(url.contains("device_id="), url)
    }
}

private final class CountingDefaults: UserDefaults {
    var pendingReads = 0
    var pendingWrites = 0
    override func bool(forKey defaultName: String) -> Bool {
        if defaultName == ApphudIdentityStore.version1RegistrationPendingKey { pendingReads += 1 }
        return super.bool(forKey: defaultName)
    }
    override func set(_ value: Bool, forKey defaultName: String) {
        if defaultName == ApphudIdentityStore.version1RegistrationPendingKey { pendingWrites += 1 }
        super.set(value, forKey: defaultName)
    }
    override func removeObject(forKey defaultName: String) {
        if defaultName == ApphudIdentityStore.version1RegistrationPendingKey { pendingWrites += 1 }
        super.removeObject(forKey: defaultName)
    }
}

private final class RecordingDelegate: ApphudDelegate {
    var userIDs: [String] = []
    func apphudDidChangeUserID(_ userID: String) { userIDs.append(userID) }
}
