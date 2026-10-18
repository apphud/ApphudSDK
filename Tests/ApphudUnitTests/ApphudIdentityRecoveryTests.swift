import XCTest
import StoreKit
@testable import ApphudSDK

/// A controlled HTTP boundary: the real SDK builds bodies and processes responses.
private final class RecoveryHTTPClient: ApphudHttpClient {
    struct Request {
        let path: ApphudEndpoint
        let params: [String: Any]
        let callback: ApphudHTTPResponseCallback?
    }
    @MainActor var requests: [Request] = []
    override var canRetry: Bool { false }

    override func startRequest(path: ApphudEndpoint, apiVersion: ApphudApiVersion = .APIV4,
                               params: [String: Any]?, method: ApphudHttpMethod,
                               useDecoder: Bool = false, retry: Bool = false,
                               requestID: String? = nil, callback: ApphudHTTPResponseCallback?) {
        Task { @MainActor in
            requests.append(Request(path: path, params: params ?? [:], callback: callback))
        }
    }

    @MainActor func respond(_ index: Int, success: Bool, user: String = "anon") throws {
        let data = try JSONSerialization.data(withJSONObject: ["data": ["results": [
            "id": "customer-\(user)", "user_id": user, "subscriptions": []
        ]]])
        requests[index].callback?(success, nil, success ? data : nil,
                                  success ? nil : ApphudError(message: "offline"), success ? 201 : 500, 0, 0)
    }
}

private final class RecoveryKeychain: ApphudKeychainStoring {
    func read(_ key: ApphudKeychainKey) -> ApphudKeychainRead { .notFound }
    func write(_ key: ApphudKeychainKey, value: String) -> Bool { true }
    func delete(_ key: ApphudKeychainKey) {}
}

private final class RecoveryInstallRecords: ApphudInstallRecordStoring {
    private var record: ApphudInstallRecord?
    func read() -> ApphudInstallRecordRead { record.map { .found($0) } ?? .missing }
    func write(_ record: ApphudInstallRecord) -> Bool { self.record = record; return true }
}

@MainActor
final class ApphudIdentityRecoveryTests: XCTestCase {
    private final class Delegate: ApphudDelegate {
        var ids: [String] = []
        func apphudDidChangeUserID(_ userID: String) { ids.append(userID) }
    }

    private func makeSDK() async throws -> (ApphudInternal, RecoveryHTTPClient, UserDefaults, String) {
        let originalSession = ApphudSession.shared
        await Task.detached { originalSession.waitForPendingWrites() }.value
        let standardKeys = ["requiresReceiptSubmissionKey", "ApphudLastUploadedTransactionsSK2",
                            "com.apphud.user_id", "com.apphud.device_id", "swizzlePaymentDisabledKey",
                            "didSubmitAppsFlyerAttributionKey", "didSubmitAdjustAttributionKey",
                            "didSubmitProductPricesKey", "didSubmitAppleAdsAttributionKey",
                            "submittedFirebaseIdKey", "submittedPushTokenKey"]
        let originalDefaults = standardKeys.map { ($0, UserDefaults.standard.object(forKey: $0)) }
        let systemKeychain = ApphudSystemKeychain()
        let originalUserKey = systemKeychain.read(.legacyUserID)
        let fileNames = [ApphudUserCacheKey, ApphudPaywallsCacheKey, ApphudPlacementsCacheKey,
                         ApphudUserPropertiesCacheKey, "ApphudUser.data"]
        let urls = [FileManager.SearchPathDirectory.cachesDirectory, .applicationSupportDirectory].flatMap { directory in
            FileManager.default.urls(for: directory, in: .userDomainMask).prefix(1).flatMap { base in
                fileNames.map { base.appendingPathComponent($0) }
            }
        }
        let files = try urls.map { url -> (URL, Data?, [FileAttributeKey: Any]) in
            guard FileManager.default.fileExists(atPath: url.path) else { return (url, nil, [:]) }
            let attributes = try FileManager.default.attributesOfItem(atPath: url.path)
            return (url, try Data(contentsOf: url), attributes.filter { $0.key == .creationDate || $0.key == .modificationDate })
        }
        let pendingProperties = await ApphudDataActor.shared.pendingUserProps
        let name = "ApphudIdentityRecoveryTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        ApphudSession.shared = ApphudSession(defaults: defaults, notificationCenter: NotificationCenter(), canPersist: { false })
        let sdk = ApphudInternal()
        addTeardownBlock { @MainActor in
            NSObject.cancelPreviousPerformRequests(withTarget: sdk)
            await ApphudDataActor.shared.setPendingUserProperties(pendingProperties)
            for (url, data, attributes) in files {
                if let data {
                    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
                    try data.write(to: url, options: .atomic)
                    try FileManager.default.setAttributes(attributes, ofItemAtPath: url.path)
                } else if FileManager.default.fileExists(atPath: url.path) {
                    try FileManager.default.removeItem(at: url)
                }
            }
            switch originalUserKey {
            case .found(let value): XCTAssertTrue(systemKeychain.write(.legacyUserID, value: value))
            case .notFound: systemKeychain.delete(.legacyUserID)
            case .unavailable: break
            }
            originalDefaults.forEach { key, value in
                if let value { UserDefaults.standard.set(value, forKey: key) }
                else { UserDefaults.standard.removeObject(forKey: key) }
            }
            ApphudSession.shared = originalSession
        }
        sdk.identityVersion = .v2
        sdk.identityStore = ApphudIdentityStore(defaults: defaults, keychain: RecoveryKeychain(), installRecords: RecoveryInstallRecords())
        sdk.identity = try XCTUnwrap(sdk.identityStore.resolve(ApphudSuppliedIDs(anonymousID: "anon", installationID: "install"))).identity
        sdk.identityStore.markSynced()
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        sdk.currentUser = try decoder.decode(ApphudUser.self, from: Data(#"{"id":"customer-anon","user_id":"anon","subscriptions":[]}"#.utf8))
        let client = RecoveryHTTPClient(); sdk.httpClient = client
        return (sdk, client, defaults, name)
    }

    private func until(_ condition: @MainActor () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(2)
        while !condition() && Date() < deadline { try? await Task.sleep(nanoseconds: 5_000_000) }
        return condition()
    }

    private func submit(_ sdk: ApphudInternal, restore: Bool, callback: @escaping ApphudNSErrorCallback) async {
        await sdk.submitReceipt(productInfo: nil, apphudProduct: nil, transactionIdentifier: nil,
                                transactionProductIdentifier: nil, transactionState: nil,
                                receiptString: "test-receipt", notifyDelegate: false,
                                restore: restore, fromScreen: false, callback: callback)
    }

    func testGeneratedAndEmptyIdentifyInputsDoNotRetryPendingIdentity() async throws {
        let (sdk, client, defaults, name) = try await makeSDK()
        defer { defaults.removePersistentDomain(forName: name) }
        defaults.set("old-generated", forKey: ApphudIdentityStore.oldDeviceIDKey)
        defaults.set(true, forKey: ApphudIdentityStore.syncPendingKey)
        var callbacks = 0
        for value in ["", "anon", "old-generated"] {
            sdk.updateUserID(userID: value) { _ in callbacks += 1 }
        }
        let completed = await until { callbacks == 3 }; XCTAssertTrue(completed)
        XCTAssertTrue(client.requests.isEmpty)
        XCTAssertNil(sdk.identifiedUserID)
    }

    func testOrdinaryConcurrentUploadsKeepSharingOneRequest() async throws {
        try await sharedUpload(version: .v2)
    }

    func testV1RestoreKeepsLegacySingleFlightAndBody() async throws {
        try await sharedUpload(version: .v1)
    }

    private func sharedUpload(version: ApphudIdentityVersion) async throws {
        let (sdk, client, defaults, name) = try await makeSDK()
        defer { defaults.removePersistentDomain(forName: name) }
        sdk.identityVersion = version
        sdk.currentDeviceID = "legacy-device"
        var callbacks = 0
        await submit(sdk, restore: false) { _ in callbacks += 1 }
        await submit(sdk, restore: version == .v1) { _ in callbacks += 1 }
        let started = await until { client.requests.count == 1 }; XCTAssertTrue(started)
        try client.respond(0, success: true)
        let completed = await until { callbacks == 2 }; XCTAssertTrue(completed)
        XCTAssertEqual(client.requests.count, 1)
        if version == .v1 {
            XCTAssertNil(client.requests[0].params["restore"])
            XCTAssertEqual(client.requests[0].params["device_id"] as? String, "legacy-device")
            XCTAssertNil(client.requests[0].params["installation_id"])
        }
    }

    func testCompatibleV2RestoresShareOneTrueUpload() async throws {
        let (sdk, client, defaults, name) = try await makeSDK()
        defer { defaults.removePersistentDomain(forName: name) }
        var callbacks = 0
        await submit(sdk, restore: true) { _ in callbacks += 1 }
        await submit(sdk, restore: true) { _ in callbacks += 1 }
        let started = await until { client.requests.count == 1 }; XCTAssertTrue(started)
        try client.respond(0, success: true)
        let completed = await until { callbacks == 2 }; XCTAssertTrue(completed)
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requests[0].params["restore"] as? Bool, true)
    }

    func testQueuedRestoreIsCanceledIfIdentityChanges() async throws {
        let (sdk, client, defaults, name) = try await makeSDK()
        defer { defaults.removePersistentDomain(forName: name) }
        var restored: [Bool] = []
        await submit(sdk, restore: false) { _ in }
        await submit(sdk, restore: true) { restored.append($0 != nil) }
        let started = await until { client.requests.count == 1 }; XCTAssertTrue(started)
        sdk.applyIdentify(userID: "another-user")
        try client.respond(0, success: true)
        let canceled = await until { restored.count == 1 }; XCTAssertTrue(canceled)
        XCTAssertEqual(restored, [true])
        XCTAssertEqual(client.requests.count, 1)
    }

    func testLogoutCancelsQueuedRestoreAndLateResponseCannotDrainNewUpload() async throws {
        let (sdk, client, defaults, name) = try await makeSDK()
        defer { defaults.removePersistentDomain(forName: name) }
        var automaticErrors: [Bool] = []
        var restoreErrors: [Bool] = []
        await submit(sdk, restore: false) { automaticErrors.append($0 != nil) }
        await submit(sdk, restore: true) { restoreErrors.append($0 != nil) }
        let first = await until { client.requests.count == 1 }; XCTAssertTrue(first)
        await sdk.logout(anonymousID: "anon")
        let canceled = await until { restoreErrors.count == 1 }; XCTAssertTrue(canceled)
        let decoder = JSONDecoder(); decoder.keyDecodingStrategy = .convertFromSnakeCase
        sdk.currentUser = try decoder.decode(ApphudUser.self, from: Data(#"{"id":"new-customer","user_id":"new-anon","subscriptions":[]}"#.utf8))
        var nextCallbacks = 0
        await submit(sdk, restore: false) { _ in nextCallbacks += 1 }
        let next = await until { client.requests.count == 2 }; XCTAssertTrue(next)
        try client.respond(0, success: true)
        for _ in 0..<10 { await Task.yield() }
        XCTAssertEqual(nextCallbacks, 0)
        XCTAssertNotNil(sdk.submittingTransaction)
        try client.respond(1, success: true, user: "new-anon")
        let completed = await until { nextCallbacks == 1 }; XCTAssertTrue(completed)
        XCTAssertEqual(automaticErrors, [true])
        XCTAssertEqual(restoreErrors, [true])
        XCTAssertEqual(client.requests.count, 2)
    }

    func testV1FailedIdentifyRetryAndSuccessfulRepeatKeepLegacyBehavior() async throws {
        let (sdk, client, defaults, name) = try await makeSDK()
        defer { defaults.removePersistentDomain(forName: name) }
        sdk.identityVersion = .v1
        sdk.v1UserID = "anon"
        sdk.currentDeviceID = "legacy-device"
        var callbacks: [String] = []
        sdk.updateUserID(userID: "Alice") { callbacks.append($0?.userId ?? "nil") }
        let first = await until { client.requests.count == 1 }; XCTAssertTrue(first)
        try client.respond(0, success: false)
        let failed = await until { callbacks.count == 1 }; XCTAssertTrue(failed)
        XCTAssertEqual(sdk.v1UserID, "anon")
        sdk.updateUserID(userID: "Alice") { callbacks.append($0?.userId ?? "nil") }
        let retried = await until { client.requests.count == 2 }; XCTAssertTrue(retried)
        guard retried else { return }
        try client.respond(1, success: true, user: "Alice")
        let synced = await until { callbacks.count == 2 && sdk.v1UserID == "Alice" }; XCTAssertTrue(synced)
        sdk.updateUserID(userID: "Alice") { callbacks.append($0?.userId ?? "nil") }
        let repeated = await until { callbacks.count == 3 }; XCTAssertTrue(repeated)
        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(callbacks, ["anon", "Alice", "Alice"])
        XCTAssertEqual(client.requests[1].params["device_id"] as? String, "legacy-device")
        XCTAssertNil(client.requests[1].params["installation_id"])
    }

    func testDifferentTransactionOwnerDoesNotReceiveForeignSuccess() async throws {
        let (sdk, client, defaults, name) = try await makeSDK()
        defer { defaults.removePersistentDomain(forName: name) }
        var firstErrors: [Bool] = []
        var secondErrors: [Bool] = []
        await submitOwned(sdk, transaction: "txn-A") { firstErrors.append($0 != nil) }
        await submitOwned(sdk, transaction: "txn-B") { secondErrors.append($0 != nil) }
        let rejected = await until { secondErrors.count == 1 && client.requests.count == 1 }; XCTAssertTrue(rejected)
        try client.respond(0, success: true)
        let finished = await until { firstErrors.count == 1 }; XCTAssertTrue(finished)
        XCTAssertEqual(firstErrors, [false])
        XCTAssertEqual(secondErrors, [true])
        XCTAssertEqual(client.requests.count, 1)
    }

    func testDuplicateTransactionOwnersShareTheirOwnAcknowledgement() async throws {
        let (sdk, client, defaults, name) = try await makeSDK()
        defer { defaults.removePersistentDomain(forName: name) }
        var errors: [Bool] = []
        await submitOwned(sdk, transaction: "txn-A") { errors.append($0 != nil) }
        await submitOwned(sdk, transaction: "txn-A") { errors.append($0 != nil) }
        let started = await until { client.requests.count == 1 }; XCTAssertTrue(started)
        try client.respond(0, success: true)
        let completed = await until { errors.count == 2 }; XCTAssertTrue(completed)
        XCTAssertEqual(errors, [false, false])
        XCTAssertEqual(client.requests.count, 1)
    }

    func testObservedTwinJoiningRestoreReceivesItsExactAcknowledgementOnce() async throws {
        let (sdk, client, defaults, name) = try await makeSDK()
        defer { defaults.removePersistentDomain(forName: name) }
        var restores = 0
        var observations = 0
        await sdk.submitReceipt(productInfo: nil, apphudProduct: nil, transactionIdentifier: "42",
                                transactionProductIdentifier: nil, transactionState: nil,
                                receiptString: "test-receipt", notifyDelegate: false,
                                restore: true, fromScreen: false) { _ in restores += 1 }
        let started = await until { client.requests.count == 1 }; XCTAssertTrue(started)
        let ticket = try XCTUnwrap(sdk.observedTransactions.beginObservation(42, identity: sdk.identity))
        await submitOwned(sdk, transaction: "42") { error in
            if sdk.observedTransactions.completeObservation(42, ticket: ticket, success: error == nil) { observations += 1 }
        }
        XCTAssertEqual(observations, 0)
        try client.respond(0, success: true)
        let completed = await until { restores == 1 }; XCTAssertTrue(completed)
        XCTAssertEqual(observations, 1)
        XCTAssertEqual(client.requests.count, 1)
        XCTAssertEqual(client.requests[0].params["restore"] as? Bool, true)
        XCTAssertNil(sdk.observedTransactions.beginObservation(42, identity: sdk.identity))
    }

    func testSameTransactionAfterIdentifyCannotJoinAnotherIdentityUpload() async throws {
        let (sdk, client, defaults, name) = try await makeSDK()
        defer { defaults.removePersistentDomain(forName: name) }
        let alice = sdk.identity
        var first: [Bool] = []
        var second: [Bool] = []
        await submitOwned(sdk, transaction: "42") { first.append($0 != nil) }
        let started = await until { client.requests.count == 1 }; XCTAssertTrue(started)
        sdk.applyIdentify(userID: "Bob")
        await submitOwned(sdk, transaction: "42") { second.append($0 != nil) }
        XCTAssertEqual(second, [true], "A's pending request cannot acknowledge B's transaction")
        try client.respond(0, success: true)
        let completed = await until { first.count == 1 }; XCTAssertTrue(completed)
        XCTAssertEqual(first, [false])
        XCTAssertEqual(second, [true])
        XCTAssertTrue(sdk.observedTransactions.hasAcknowledgement(42, identity: alice))
        XCTAssertFalse(sdk.observedTransactions.hasAcknowledgement(42, identity: sdk.identity))
        XCTAssertEqual(client.requests.count, 1)
    }

    func testRestoreAfterIdentifySendsTrueForTheNewIdentity() async throws {
        let (sdk, client, defaults, name) = try await makeSDK()
        defer { defaults.removePersistentDomain(forName: name) }
        var first = 0
        var second = 0
        await submit(sdk, restore: true) { _ in first += 1 }
        let started = await until { client.requests.count == 1 }; XCTAssertTrue(started)
        sdk.applyIdentify(userID: "Bob")
        await submit(sdk, restore: true) { _ in second += 1 }
        try client.respond(0, success: true)
        let next = await until { client.requests.count == 2 }; XCTAssertTrue(next)
        XCTAssertEqual(first, 1)
        XCTAssertEqual(second, 0)
        guard next else { return }
        XCTAssertEqual(client.requests[1].params["user_id"] as? String, "Bob")
        XCTAssertEqual(client.requests[1].params["restore"] as? Bool, true)
        try client.respond(1, success: true, user: "Bob")
        let finished = await until { second == 1 }; XCTAssertTrue(finished)
    }

    func testCompletedExactTransactionReusesOnlyItsOwnIdentityAcknowledgement() async throws {
        let (sdk, client, defaults, name) = try await makeSDK()
        defer { defaults.removePersistentDomain(forName: name) }
        var callbacks = 0
        await submitOwned(sdk, transaction: "42") { _ in callbacks += 1 }
        let started = await until { client.requests.count == 1 }; XCTAssertTrue(started)
        try client.respond(0, success: true)
        let first = await until { callbacks == 1 }; XCTAssertTrue(first)
        await submitOwned(sdk, transaction: "42") { _ in callbacks += 1 }
        XCTAssertEqual(callbacks, 2)
        XCTAssertEqual(client.requests.count, 1)
        sdk.applyIdentify(userID: "Bob")
        await submitOwned(sdk, transaction: "42") { _ in callbacks += 1 }
        let next = await until { client.requests.count == 2 }; XCTAssertTrue(next)
        guard next else { return }
        XCTAssertEqual(client.requests[1].params["user_id"] as? String, "Bob")
        try client.respond(1, success: true, user: "Bob")
        let finished = await until { callbacks == 3 }; XCTAssertTrue(finished)
        await submit(sdk, restore: true) { _ in callbacks += 1 }
        let restored = await until { client.requests.count == 3 }; XCTAssertTrue(restored)
        guard restored else { return }
        XCTAssertEqual(client.requests[2].params["restore"] as? Bool, true)
        try client.respond(2, success: true, user: "Bob")
        let done = await until { callbacks == 4 }; XCTAssertTrue(done)
    }

    private func submitOwned(_ sdk: ApphudInternal, transaction: String, callback: @escaping ApphudNSErrorCallback) async {
        await sdk.submitReceipt(productInfo: nil, apphudProduct: nil, transactionIdentifier: transaction,
                                transactionProductIdentifier: nil, transactionState: nil,
                                receiptString: "test-receipt", notifyDelegate: false,
                                ownsTransaction: true, fromScreen: false, callback: callback)
    }

    func testDeferredRestoreRevalidatesSessionWhenClaimingTheUpload() async throws {
        let (sdk, client, defaults, name) = try await makeSDK()
        defer { defaults.removePersistentDomain(forName: name) }
        let context = (sdk.receiptSessionGeneration, sdk.identity)
        // The supplied anonymous id can be unchanged across logout: identity alone is insufficient.
        await sdk.logout(anonymousID: "anon")
        var errors: [Bool] = []
        await sdk.submitReceipt(productInfo: nil, apphudProduct: nil, transactionIdentifier: nil,
                                transactionProductIdentifier: nil, transactionState: nil,
                                receiptString: "test-receipt", notifyDelegate: false,
                                restore: true, fromScreen: false, restoreContext: context) { errors.append($0 != nil) }
        XCTAssertEqual(errors, [true])
        XCTAssertNil(sdk.submittingTransaction)
        XCTAssertTrue(client.requests.isEmpty)
    }

    func testPendingIdentifyRetriesSameIDThenSuccessfulRepeatIsNoOp() async throws {
        let (sdk, client, defaults, name) = try await makeSDK()
        defer { defaults.removePersistentDomain(forName: name) }
        let delegate = Delegate(); sdk.delegate = delegate
        var callbacks: [String] = []
        sdk.updateUserID(userID: "Alice") { callbacks.append($0?.userId ?? "nil") }
        let first = await until { client.requests.count == 1 }; XCTAssertTrue(first)
        try client.respond(0, success: false)
        let failed = await until { callbacks.count == 1 }; XCTAssertTrue(failed)
        XCTAssertTrue(sdk.identityStore.isSyncPending)

        sdk.updateUserID(userID: "Alice") { callbacks.append($0?.userId ?? "nil") }
        let retried = await until { client.requests.count == 2 }
        XCTAssertTrue(retried, "a pending Identify needs another registration")
        guard retried else { return }
        XCTAssertEqual(client.requests[1].params["user_id"] as? String, "Alice")
        try client.respond(1, success: true, user: "Alice")
        let synced = await until { callbacks.count == 2 && !sdk.identityStore.isSyncPending }; XCTAssertTrue(synced)
        sdk.updateUserID(userID: "Alice") { callbacks.append($0?.userId ?? "nil") }
        let repeated = await until { callbacks.count == 3 }; XCTAssertTrue(repeated)
        XCTAssertEqual(client.requests.count, 2)
        XCTAssertEqual(callbacks, ["anon", "Alice", "Alice"])
        XCTAssertEqual(delegate.ids, ["Alice"])
        XCTAssertEqual(sdk.identity.installationID, "install")
        XCTAssertEqual(sdk.identity.anonymousID, "anon")
    }

    func testExplicitRestoreFollowingAutomaticUploadSendsItsOwnTrueRequest() async throws {
        try await restoreFollowingAutomatic(success: true)
    }

    func testExplicitRestoreFollowingFailedAutomaticUploadStillSendsTrue() async throws {
        try await restoreFollowingAutomatic(success: false)
    }

    private func restoreFollowingAutomatic(success: Bool) async throws {
        let (sdk, client, defaults, name) = try await makeSDK()
        defer { defaults.removePersistentDomain(forName: name) }
        var automaticCallbacks = 0
        var restoreCallbacks = 0
        await submit(sdk, restore: false) { _ in automaticCallbacks += 1 }
        let first = await until { client.requests.count == 1 }; XCTAssertTrue(first)
        await submit(sdk, restore: true) { _ in restoreCallbacks += 1 }
        XCTAssertEqual(restoreCallbacks, 0)
        try client.respond(0, success: success)
        let next = await until { client.requests.count == 2 }
        XCTAssertTrue(next, "Restore must reach the backend with true")
        XCTAssertEqual(automaticCallbacks, 1)
        XCTAssertEqual(restoreCallbacks, 0, "false response must not answer the explicit Restore")
        guard next else { return }
        XCTAssertEqual(client.requests.map { $0.params["restore"] as? Bool }, [false, true])
        try client.respond(1, success: true)
        let finished = await until { restoreCallbacks == 1 }; XCTAssertTrue(finished)
    }
}
