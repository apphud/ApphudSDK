//
//  ApphudIdentityTests.swift
//  ApphudUnitTests
//
//  installation_id, anonymous_id and user_id, and reinstall detection.
//  One test per row of the ticket's identity model table, of the amendment's launch-flow
//  table and of the amendment's test list.
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
    private(set) var accessCount = 0

    func read(_ key: ApphudKeychainKey) -> ApphudKeychainRead {
        accessCount += 1
        if locked || readsFail { return .unavailable }
        return items[key].map { .found($0) } ?? .notFound
    }

    func write(_ key: ApphudKeychainKey, value: String) -> Bool {
        accessCount += 1
        if locked { return false }
        items[key] = value
        return true
    }

    func delete(_ key: ApphudKeychainKey) {
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

    func read() -> ApphudInstallRecordRead {
        if unreadable { return .unreadable }
        if damaged { return .damaged }
        return record.map { .found($0) } ?? .missing
    }

    func write(_ record: ApphudInstallRecord) -> Bool {
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

    override func setUp() {
        super.setUp()
        keychain = FakeKeychain()
        installApp()
    }

    override func tearDown() {
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

    private func customerParams(_ identity: ApphudIdentity) -> [String: Any] {
        ApphudInternal.customerIdentityParams(identity, legacyWeb2Web: false, serverUserID: nil)
    }

    // MARK: - Identity model table (ticket description)

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

    // MARK: - Launch-flow table (amendment)

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

    func testFlowNoInstallationID_OnlyOldKeychainKey_IsReinstall() {
        keychain.items[.legacyDeviceID] = "OLD-DEVICE"

        XCTAssertEqual(launch().identity.isReinstall, true)
    }

    func testFlowNoInstallationID_OnlyOldKeychainKeyBlank_IsReinstall() {
        keychain.items[.legacyDeviceID] = ""

        XCTAssertEqual(launch().identity.isReinstall, true, "an old key counts even when blanked by logout")
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

    func testFlowAfterDeciding_ResultSavedKeyWrittenOldKeysDeleted() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE", inUserDefaults: false)

        let identity = launch().identity

        XCTAssertEqual(installRecords.record?.installationID, identity.installationID)
        XCTAssertEqual(installRecords.record?.isReinstall, true, "saved next to installation_id")
        XCTAssertNotNil(keychain.items[.reinstall])
        XCTAssertNil(keychain.items[.legacyDeviceID])
        XCTAssertNil(keychain.items[.legacyUserID])
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

    // MARK: - Amendment test list

    func testAmendmentDeleteReinstall_TrueAndRegistrationsCarryReinstall() {
        launch()
        deleteAndReinstallApp()

        let identity = launch().identity

        XCTAssertEqual(identity.isReinstall, true)
        XCTAssertEqual(customerParams(identity)["reinstall"] as? Bool, true)
        let relaunch = launch()
        XCTAssertEqual(relaunch.identity.isReinstall, true, "every registration of this install carries it")
        XCTAssertEqual(relaunch.launch, .normal, "only the install's first launch counts as new")
    }

    func testAmendmentFreshInstall_FalseAndNoParam() {
        let identity = launch().identity

        XCTAssertEqual(identity.isReinstall, false)
        XCTAssertNil(customerParams(identity)["reinstall"])
    }

    func testAmendmentBackupRestoredOntoAnotherPhone_False() {
        // Made after the upgrade: the old keys are gone by then.
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        let original = launch().identity

        restoreBackupOntoAnotherPhone()
        let restored = launch().identity

        XCTAssertEqual(restored.isReinstall, false)
        XCTAssertNotEqual(restored.installationID, original.installationID, "the installation id is new on another phone")
    }

    func testAmendmentLogoutDeleteReinstall_True() {
        var identity = launch().identity
        makeStore().logout(anonymousID: nil, &identity)

        deleteAndReinstallApp()

        XCTAssertEqual(launch().identity.isReinstall, true, "logout never removes the key")
    }

    func testAmendmentReinstallStraightFromOldSDK_True() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE", inUserDefaults: false)

        XCTAssertEqual(launch().identity.isReinstall, true)
    }

    func testAmendmentUpdatedThenDeletedAndReinstalled_True() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        launch()

        deleteAndReinstallApp()

        XCTAssertEqual(launch().identity.isReinstall, true)
    }

    func testAmendmentKeychainUnreadableAtFirstLaunch_NilNoParam_ResolvedLater() {
        keychain.locked = true
        let first = launch().identity
        XCTAssertNil(first.isReinstall)
        XCTAssertNil(customerParams(first)["reinstall"])

        keychain.locked = false
        XCTAssertEqual(launch().identity.isReinstall, false)
    }

    // MARK: - Ticket acceptance

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

    func testUpgradeSDKGeneratedLegacyUserIDBecomesAnonymousID() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")

        let identity = launch().identity

        XCTAssertEqual(identity.anonymousID, "OLD-DEVICE")
        XCTAssertNil(identity.userID)
        XCTAssertNil(defaults.string(forKey: "com.apphud.device_id"), "removed, so a later backup restore starts fresh")
    }

    func testUpgradeRealLegacyUserIDStaysUserID() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "alice@example.com")

        let identity = launch().identity

        XCTAssertEqual(identity.installationID, "OLD-DEVICE")
        XCTAssertEqual(identity.userID, "alice@example.com")
        XCTAssertNotEqual(identity.anonymousID, "OLD-DEVICE")
        XCTAssertEqual(customerParams(identity)["user_id"] as? String, "alice@example.com")
    }

    func testUpgradeKeepsOnlyTheReinstallKeyInKeychain() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")

        launch()

        XCTAssertEqual(Set(keychain.items.keys), [.reinstall])
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

    // MARK: - Request fields (backend contract)

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
        let saved = ApphudInternal.shared.identity
        defer { ApphudInternal.shared.identity = saved }
        let sdk = ApphudInternal.shared

        sdk.identity = ApphudIdentity(installationID: "inst-1", anonymousID: "anon-1", userID: nil, isReinstall: true)
        var body = sdk.customerRequestParams(fields: ["initial_call": true], legacyWeb2Web: false)
        XCTAssertEqual(body["installation_id"] as? String, "inst-1")
        XCTAssertEqual(body["anonymous_id"] as? String, "anon-1")
        XCTAssertEqual(body["reinstall"] as? Bool, true)
        XCTAssertNil(body["device_id"])
        XCTAssertNil(body["user_id"])
        XCTAssertNotNil(body["first_seen"], "sent with reinstall")

        sdk.identity = ApphudIdentity(installationID: "inst-1", anonymousID: "anon-1", userID: "Alice", isReinstall: false)
        body = sdk.customerRequestParams(fields: [:], legacyWeb2Web: false)
        XCTAssertEqual(body["user_id"] as? String, "Alice")
        XCTAssertNil(body["reinstall"])

        body = sdk.customerRequestParams(fields: ["from_web2web": true, "email": "a@b.c"], legacyWeb2Web: true)
        XCTAssertEqual(body["device_id"] as? String, "inst-1")
        XCTAssertNil(body["installation_id"])
        XCTAssertNil(body["anonymous_id"])
        XCTAssertEqual(body["from_web2web"] as? Bool, true)
    }

    func testWeb2WebByEmailKeepsTheOldShape() {
        let identity = ApphudIdentity(installationID: "inst-1", anonymousID: "anon-1", userID: nil, isReinstall: true)

        let params = ApphudInternal.customerIdentityParams(identity, legacyWeb2Web: true, serverUserID: "anon-1")

        XCTAssertEqual(params["device_id"] as? String, "inst-1", "device_id holds the installation id")
        XCTAssertNil(params["anonymous_id"], "the backend rejects from_web2web with the new ids")
        XCTAssertNil(params["installation_id"])
        XCTAssertEqual(params["user_id"] as? String, "anon-1", "user_id as old SDKs sent it")
        XCTAssertEqual(params["reinstall"] as? Bool, true, "every POST /v1/customers of a reinstalled install carries it")
    }

    func testWeb2WebByEmailAdoptsOnlyAnotherCustomer() {
        let webUser = ApphudUser(userID: "web-user")
        let sameCustomer = ApphudUser(userID: "cust-1")

        XCTAssertEqual(ApphudInternal.webUserToAdopt(customerBefore: "cust-1", response: webUser, anonymousID: "anon-1"), "web-user")
        XCTAssertNil(ApphudInternal.webUserToAdopt(customerBefore: "cust-1", response: sameCustomer, anonymousID: "anon-1"),
                     "no match: the same customer comes back, its user_id may be another install's id")
        XCTAssertNil(ApphudInternal.webUserToAdopt(customerBefore: "cust-1", response: ApphudUser(userID: "anon-1"), anonymousID: "anon-1"))
        XCTAssertNil(ApphudInternal.webUserToAdopt(customerBefore: "cust-1", response: nil, anonymousID: "anon-1"))
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
        XCTAssertEqual(sdk.customerRequestParams(fields: [:], legacyWeb2Web: false)["idfv"] as? String, systemIDFV,
                       "POST /v1/customers carries the IDFV the host never passed")

        ApphudUtils.shared.optOutOfTracking = true
        XCTAssertNil(sdk.customerRequestParams(fields: [:], legacyWeb2Web: false)["idfv"])
    }
    #endif

    // MARK: - Embedded mode (amendment)

    func testEmbeddedModeTakesIsReinstallFromHostAndNeverTouchesKeychain() {
        keychain.items[.legacyDeviceID] = "HOST-OLD"

        let identity = launch(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "host-inst", isReinstall: true)).identity

        XCTAssertEqual(identity.isReinstall, true)
        XCTAssertEqual(keychain.accessCount, 0, "the embedded SDK runs no detection of its own")
        XCTAssertEqual(keychain.items[.legacyDeviceID], "HOST-OLD", "the host's old key stays for its own migration")
    }

    func testEmbeddedModeUnknownReinstallFromHostSendsNoParam() {
        let identity = launch(ApphudSuppliedIDs(anonymousID: "host-anon", installationID: "host-inst", isReinstall: nil)).identity

        XCTAssertNil(identity.isReinstall)
        XCTAssertNil(customerParams(identity)["reinstall"])
        XCTAssertEqual(keychain.accessCount, 0)
    }

    func testEmbeddedModeNoUserIDMeansNoUser() {
        launch(ApphudSuppliedIDs(userID: "Alice", anonymousID: "host-anon", installationID: "host-inst"))

        let identity = launch(ApphudSuppliedIDs(anonymousID: "host-anon-2", installationID: "host-inst")).identity

        XCTAssertNil(identity.userID, "the host has no user: the stored one is not brought back")
        XCTAssertEqual(identity.anonymousID, "host-anon-2")
    }

    // MARK: - Review fixes

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

    func testOldKeychainItemsDeletedOnALaterLaunchWhenTheUpgradeLaunchWasLocked() {
        seedOldSDK(deviceID: "OLD-DEVICE", userID: "OLD-DEVICE")
        keychain.locked = true
        launch()
        XCTAssertNotNil(keychain.items[.legacyDeviceID])

        keychain.locked = false
        launch()

        XCTAssertEqual(Set(keychain.items.keys), [.reinstall])
    }

    func testOldKeychainItemsDeletedAfterAReinstallCheckDecidedLater() {
        keychain.items[.legacyDeviceID] = "OLD-DEVICE"
        keychain.locked = true
        launch()

        keychain.locked = false
        let identity = launch().identity

        XCTAssertEqual(identity.isReinstall, true)
        XCTAssertEqual(Set(keychain.items.keys), [.reinstall])
    }

    func testNormalLaunchSkipsTheKeychainOnceItIsUpdated() {
        launch()
        let accesses = keychain.accessCount

        launch()

        XCTAssertEqual(keychain.accessCount, accesses, "no Keychain call on a normal launch")
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

    func testLegacyDeviceIDKeyRemovedOnALaterLaunchIfStillThere() {
        launch()
        defaults.set("OLD-DEVICE", forKey: "com.apphud.device_id")

        launch()

        XCTAssertNil(defaults.string(forKey: "com.apphud.device_id"))
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

    // MARK: - Review round 2

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

    func testMarkSyncedOnlyForASuccessfulNewShapeRequestWithCurrentIDs() {
        let sent = ApphudIdentity(installationID: "i", anonymousID: "a")
        var identified = sent
        identified.userID = "Alice"

        XCTAssertTrue(ApphudInternal.shouldMarkSynced(done: true, legacyWeb2Web: false, sent: sent, current: sent))
        XCTAssertFalse(ApphudInternal.shouldMarkSynced(done: false, legacyWeb2Web: false, sent: sent, current: sent))
        XCTAssertFalse(ApphudInternal.shouldMarkSynced(done: true, legacyWeb2Web: true, sent: sent, current: sent),
                       "the old web-to-web shape carries no anonymous_id")
        XCTAssertFalse(ApphudInternal.shouldMarkSynced(done: true, legacyWeb2Web: false, sent: sent, current: identified),
                       "an identify while the request was out is still unsent")
    }

    func testQueryValueEscapesSeparators() {
        let escaped = "a&b=c+d?e#f".addingPercentEncoding(withAllowedCharacters: .apphudQueryValueAllowed) ?? ""

        XCTAssertEqual(escaped, "a%26b%3Dc%2Bd%3Fe%23f")
    }

    // MARK: - Review round 3

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

    func testSaveAfterLogoutRestoresTheLogoutStateAndMarksPending() {
        var identity = launch().identity
        let store = makeStore()
        store.logout(anonymousID: "anon-new", &identity)
        // An identify that ran with the old ids while logout awaited.
        var stale = ApphudIdentity(installationID: identity.installationID, anonymousID: "anon-old", userID: "Bob")
        _ = store.identify("Bob", &stale)
        store.markSynced()

        store.save(identity)

        let relaunched = launch().identity
        XCTAssertEqual(relaunched.anonymousID, "anon-new")
        XCTAssertNil(relaunched.userID)
        XCTAssertTrue(makeStore().isSyncPending)
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

private final class RecordingDelegate: ApphudDelegate {
    var userIDs: [String] = []
    func apphudDidChangeUserID(_ userID: String) { userIDs.append(userID) }
}
