//
//  ApphudSDKTests.swift
//  ApphudSDKTests
//
//  StoreKitTest-based integration harness for the SDK.
//
//  All network traffic is intercepted by ApphudStubURLProtocol (no live backend),
//  purchases run against the local StoreKit.storekit configuration via SKTestSession.
//
//  These tests pin the CURRENT behavior of the purchase pipeline (baseline before
//  the StoreKit 2 migration): what gets sent to POST /v4/subscriptions and what
//  the purchase callback returns.
//

import XCTest
@testable import ApphudSDK
import StoreKit
import StoreKitTest

// MARK: - Network stub

/// Intercepts all Apphud gateway traffic, records request payloads and serves fixtures.
final class ApphudStubURLProtocol: URLProtocol {

    struct RecordedRequest {
        let method: String
        let path: String
        let body: [String: Any]
    }

    private static let lock = NSLock()
    private static var _requests: [RecordedRequest] = []

    static var requests: [RecordedRequest] {
        lock.lock(); defer { lock.unlock() }
        return _requests
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        _requests.removeAll()
    }

    /// Paths of every request outside `/v4` since the suite started; `reset()` keeps them.
    private static var _unversionedPaths: [String] = []

    static var unversionedPaths: [String] {
        lock.lock(); defer { lock.unlock() }
        return _unversionedPaths
    }

    static func clearUnversionedPaths() {
        lock.lock(); defer { lock.unlock() }
        _unversionedPaths.removeAll()
    }

    static func record(_ request: RecordedRequest) {
        lock.lock(); defer { lock.unlock() }
        _requests.append(request)
        if !request.path.hasPrefix("/v4/") {
            _unversionedPaths.append(request.path)
        }
    }

    static func requests(to pathSuffix: String) -> [RecordedRequest] {
        requests.filter { $0.path.hasSuffix(pathSuffix) }
    }

    /// Artificial latency for POST /v4/subscriptions, so a test can keep a submission
    /// in flight and exercise concurrent delivery of the same transaction.
    static var subscriptionsResponseDelay: TimeInterval = 0

    /// When set, POST /v4/subscriptions answers with this status instead of 200, so the
    /// failure paths (where purchases are lost) are exercisable.
    static var subscriptionsFailureStatus: Int?

    /// Artificial latency for POST /v4/sign_offer, so a test can change the user state
    /// between signing a promotional offer and purchasing it.
    static var signOfferResponseDelay: TimeInterval = 0

    override class func canInit(with request: URLRequest) -> Bool {
        guard let host = request.url?.host else { return false }
        return host.contains("apphud.com") || host.contains("aphd.cc")
    }

    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let url = request.url!
        let path = url.path
        let body = Self.readBodyJSON(from: request)
        Self.record(RecordedRequest(method: request.httpMethod ?? "", path: path, body: body))

        let isSubscriptions = path.hasSuffix("/subscriptions")
        let statusCode = isSubscriptions ? (Self.subscriptionsFailureStatus ?? 200) : 200
        let json = statusCode == 200 ? Self.fixture(for: path, requestBody: body) : ["errors": ["stubbed failure"]]
        let data = try! JSONSerialization.data(withJSONObject: json)
        let response = HTTPURLResponse(url: url, statusCode: statusCode, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!

        let deliver = { [weak self] in
            guard let self else { return }
            self.client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
            self.client?.urlProtocol(self, didLoad: data)
            self.client?.urlProtocolDidFinishLoading(self)
        }

        let delay = isSubscriptions ? Self.subscriptionsResponseDelay : (path.hasSuffix("/sign_offer") ? Self.signOfferResponseDelay : 0)
        if delay > 0 {
            DispatchQueue.global().asyncAfter(deadline: .now() + delay, execute: deliver)
        } else {
            deliver()
        }
    }

    override func stopLoading() {}

    // URLSession moves httpBody into a stream before the protocol sees the request.
    private static func readBodyJSON(from request: URLRequest) -> [String: Any] {
        var data = request.httpBody
        if data == nil, let stream = request.httpBodyStream {
            stream.open()
            defer { stream.close() }
            var collected = Data()
            let bufferSize = 16_384
            let buffer = UnsafeMutablePointer<UInt8>.allocate(capacity: bufferSize)
            defer { buffer.deallocate() }
            while stream.hasBytesAvailable {
                let read = stream.read(buffer, maxLength: bufferSize)
                if read <= 0 { break }
                collected.append(buffer, count: read)
            }
            data = collected
        }
        guard let data, let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return [:] }
        return json
    }

    // MARK: Fixtures

    private static func fixture(for path: String, requestBody: [String: Any]) -> [String: Any] {
        if path.hasSuffix("/customers") {
            return userResponse(subscriptions: [])
        }
        if path.hasSuffix("/subscriptions") {
            let productId = purchasedProductId(from: requestBody) ?? "com.apphud.weekly"
            return userResponse(subscriptions: [subscriptionFixture(productId: productId)])
        }
        if path.hasSuffix("/sign_offer") {
            // Well-formed but not a real signature: StoreKitTest does not verify it.
            return ["data": ["results": ["key_id": "STUBKEYID",
                                         "data": ["nonce": UUID().uuidString.lowercased(),
                                                  "signature": Data("stub-signature".utf8).base64EncodedString(),
                                                  "timestamp": Int(Date().timeIntervalSince1970 * 1000)]]]]
        }
        // Generic empty payload for auxiliary endpoints (events, logs, products, paywalls...).
        return ["data": ["results": [:]]]
    }

    private static func purchasedProductId(from body: [String: Any]) -> String? {
        if let info = body["product_info"] as? [String: Any], let pid = info["product_id"] as? String {
            return pid
        }
        return nil
    }

    private static func userResponse(subscriptions: [[String: Any]]) -> [String: Any] {
        let user: [String: Any] = [
            "user_id": ApphudTestConstants.userId,
            "id": "internal-\(ApphudTestConstants.userId)",
            "subscriptions": subscriptions,
            "paywalls": [paywallFixture()],
            "placements": [placementFixture()],
            "total_devices_count": 1
        ]
        return ["data": ["results": user]]
    }

    // The real backend always serves placements/paywalls with the user; the empty
    // arrays of the early harness were a simplification. Snake_case keys: the SDK
    // decodes with .convertFromSnakeCase.
    private static func paywallFixture() -> [String: Any] {
        [
            "id": "pw_1",
            "name": "Main Paywall",
            "identifier": "main_paywall",
            "default": true,
            "items": [[
                "id": "bundle_1",
                "item_id": "item_1",
                "name": "Weekly",
                "store": "app_store",
                "product_id": ApphudTestConstants.weeklyProductId
            ]]
        ]
    }

    private static func placementFixture() -> [String: Any] {
        [
            "id": "plc_1",
            "identifier": "main",
            "paywalls": [paywallFixture()]
        ]
    }

    private static func subscriptionFixture(productId: String) -> [String: Any] {
        [
            "kind": "autorenewable",
            "id": "sub_1",
            "product_id": productId,
            "expires_at": "2030-01-01T00:00:00.000Z",
            "started_at": "2026-01-01T00:00:00.000Z",
            "in_retry_billing": false,
            "autorenew_enabled": true,
            "introductory_activated": false,
            "environment": "sandbox",
            "local": false,
            "group_id": "group_1",
            "status": "regular",
            "original_transaction_id": "100000000000001",
            "transaction_id": "100000000000001"
        ]
    }
}

/// Reference box for a purchase result delivered via a callback the test must outlive.
final class ApphudResultBox: @unchecked Sendable {
    var result: ApphudPurchaseResult?
}

extension ApphudSDKTests {
    /// Decodes the payload segment of a JWS (base64url JSON) — the signature is not
    /// verified here; tests only pin WHICH transaction the token was signed for.
    static func jwsPayloadJSON(_ jws: String?) -> [String: Any]? {
        guard let segments = jws?.components(separatedBy: "."), segments.count == 3 else { return nil }
        var base64 = segments[1]
            .replacingOccurrences(of: "-", with: "+")
            .replacingOccurrences(of: "_", with: "/")
        while base64.count % 4 != 0 { base64 += "=" }
        guard let data = Data(base64Encoded: base64) else { return nil }
        return (try? JSONSerialization.jsonObject(with: data)) as? [String: Any]
    }
}

enum ApphudTestConstants {
    static let apiKey = "app_stubbed_key"
    // Unique per test run: the SDK caches the registered user on disk between
    // launches, and a cached user would short-circuit the network registration.
    static let userId = "unit_test_user_\(UUID().uuidString.prefix(8))"
    static let weeklyProductId = "com.apphud.weekly"
}

// MARK: - Baseline tests (StoreKit 1 pipeline, pre-migration)

final class ApphudSDKTests: XCTestCase {

    static var sdkStarted = false
    // One shared StoreKitTest session for the whole suite: individual sessions are
    // deallocated with their tests, and unfinished transactions from a previous run
    // would otherwise be redelivered into the next one.
    static var storeKitSession: SKTestSession?

    override class func setUp() {
        super.setUp()
        // Must be installed BEFORE the first access to ApphudHttpClient.shared.
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ApphudStubURLProtocol.self]
        ApphudHttpClient.testURLSessionConfiguration = config

        storeKitSession = try? SKTestSession(configurationFileNamed: "StoreKit")
        storeKitSession?.disableDialogs = true
        // NOTE: do NOT touch failTransactionsEnabled here — on this simulator runtime
        // ANY write to the flag (even `false`) makes storekitd fail every subsequent
        // purchase with StoreKitError.unknown until device erase. Same Apple-bug family
        // as the 26.4/26.5 interception breakage; the failure-injection test was removed
        // for the same reason.
        // Drop unfinished transactions left over from previous test runs BEFORE the
        // SDK starts and its Transaction.updates listener begins redelivering them.
        storeKitSession?.clearTransactions()
    }

    override func tearDown() {
        XCTAssertEqual(ApphudStubURLProtocol.unversionedPaths, [], "every request goes to /v4")
        ApphudStubURLProtocol.clearUnversionedPaths()
        super.tearDown()
        // Tracking a foreign purchase force-enables observer mode process-wide; reset it
        // so test order (or running a single test) can't change what other tests observe.
        ApphudUtils.shared.storeKitObserverMode = false
        ApphudStubURLProtocol.subscriptionsResponseDelay = 0
        ApphudStubURLProtocol.subscriptionsFailureStatus = nil
        ApphudStubURLProtocol.signOfferResponseDelay = 0
    }

    @MainActor
    private func startSDKIfNeeded() async {
        guard !Self.sdkStarted else { return }
        Self.sdkStarted = true

        Apphud.enableDebugLogs()
        await withCheckedContinuation { continuation in
            Apphud.startManually(apiKey: ApphudTestConstants.apiKey,
                                 userID: ApphudTestConstants.userId,
                                 deviceID: ApphudTestConstants.userId,
                                 identityVersion: .v2) { _ in
                continuation.resume()
            }
        }
    }

    // MARK: 1. Registration through the stub

    @MainActor
    func test1RegisterParsesStubbedUser() async throws {
        await startSDKIfNeeded()

        XCTAssertEqual(Apphud.userID(), ApphudTestConstants.userId)

        // The start callback can fire from a cached user while the network
        // registration is still in flight — poll for the request.
        var registrations: [ApphudStubURLProtocol.RecordedRequest] = []
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline {
            registrations = ApphudStubURLProtocol.requests(to: "/customers")
            if !registrations.isEmpty { break }
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        XCTAssertFalse(registrations.isEmpty, "SDK must register the user via POST /v4/customers")
        XCTAssertEqual(registrations.last?.method, "POST")
        XCTAssertEqual(registrations.last?.path, "/v4/customers")
    }

    // MARK: 1c. The old device_id goes until a registration succeeds

    @MainActor
    func test1cRegistrationSendsTheOldDeviceIDUntilOneSucceeds() async throws {
        await startSDKIfNeeded()
        let file = ApphudInstallRecordFile.standard
        guard case .found(let saved) = file.read() else { return XCTFail("the SDK keeps an install record") }
        defer { _ = file.write(saved) }
        var record = saved
        record.legacyDeviceID = "OLD-DEVICE"
        XCTAssertTrue(file.write(record))

        // Tagged: the launch registration may still be on its way.
        func register(_ probe: Int) async throws -> ApphudStubURLProtocol.RecordedRequest? {
            ApphudInternal.shared.updateUser(fields: ["test_probe": probe]) { _, _, _, _, _, _, _ in }
            let deadline = Date().addingTimeInterval(10)
            var mine: ApphudStubURLProtocol.RecordedRequest?
            while mine == nil && Date() < deadline {
                try await Task.sleep(nanoseconds: 100_000_000)
                mine = ApphudStubURLProtocol.requests(to: "/customers").last { $0.body["test_probe"] as? Int == probe }
            }
            return mine
        }

        let first = try await register(1)
        XCTAssertEqual(first?.body["legacy_device_id"] as? String, "OLD-DEVICE")
        let deadline = Date().addingTimeInterval(5)
        while case .found(let current) = file.read(), current.legacyDeviceID != nil, Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let second = try await register(2)
        XCTAssertNotNil(second, "a second registration went out")
        XCTAssertNil(second?.body["legacy_device_id"], "not after a registration succeeded")
    }

    // MARK: 1d. The first launch after an update: the registration first, the rest after it

    @MainActor
    func test1dHeldRequestsGoAfterTheFirstRegistration() async throws {
        await startSDKIfNeeded()
        let sdk = ApphudInternal.shared
        let settle = Date().addingTimeInterval(10)
        while sdk.isRegisteringUser && Date() < settle {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        try await Task.sleep(nanoseconds: 300_000_000)
        let client = ApphudHttpClient.shared
        let hold = client.firstRegistrationHold
        defer { hold.open() }
        ApphudStubURLProtocol.reset()
        hold.close()

        client.startRequest(path: .events, params: ["name": "held_event"], method: .post, callback: nil)
        client.startRequest(path: .subscriptions, params: ["environment": "sandbox"], method: .post, callback: nil)
        try await Task.sleep(nanoseconds: 300_000_000)
        XCTAssertTrue(ApphudStubURLProtocol.requests(to: "/events").isEmpty, "held until the first registration answers")
        XCTAssertFalse(ApphudStubURLProtocol.requests(to: "/subscriptions").isEmpty, "purchases carry legacy_device_id and go on")

        sdk.updateUser(fields: ["test_probe": 4]) { _, _, _, _, _, _, _ in }
        let deadline = Date().addingTimeInterval(5)
        while ApphudStubURLProtocol.requests(to: "/events").isEmpty && Date() < deadline {
            try await Task.sleep(nanoseconds: 100_000_000)
        }
        let paths = ApphudStubURLProtocol.requests.map(\.path)
        let registration = try XCTUnwrap(paths.firstIndex(of: "/v4/customers"), "the registration went out")
        let event = try XCTUnwrap(paths.firstIndex(of: "/v4/events"), "the held event went out")
        XCTAssertLessThan(registration, event, "the registration went first")
    }

    // MARK: 1b. Placements, paywalls and priced products are available after start

    /// Core-functionality contract: after SDK start the backend's placements arrive with
    /// their paywalls and products, and each product resolves to a live StoreKit 2
    /// product with a real price — the exact chain a client's paywall screen depends on.
    @MainActor
    func test1bPlacementsPaywallsAndPricedProductsAreAvailable() async throws {
        await startSDKIfNeeded()

        let placements = await Apphud.placements()
        XCTAssertEqual(placements.count, 1, "The stubbed backend serves exactly one placement")
        let placement = try XCTUnwrap(placements.first)
        XCTAssertEqual(placement.identifier, "main")

        let paywall = try XCTUnwrap(placement.paywall, "Placement must carry its paywall")
        XCTAssertEqual(paywall.identifier, "main_paywall")
        XCTAssertEqual(paywall.products.count, 1, "Paywall must carry its products")

        let product = try XCTUnwrap(paywall.products.first)
        XCTAssertEqual(product.productId, ApphudTestConstants.weeklyProductId)

        let resolvedProduct = try await product.product()
        let storeProduct = try XCTUnwrap(resolvedProduct, "ApphudProduct must resolve to a StoreKit 2 Product")
        XCTAssertGreaterThan(storeProduct.price, 0, "Product must carry a real price")
        XCTAssertFalse(storeProduct.displayPrice.isEmpty, "Product must carry a display price")
    }

    // MARK: 8. A promotional offer purchase sends exactly the appAccountToken it signed

    // Apple checks the offer signature against the purchase's appAccountToken in lowercase,
    // or against "" when the purchase sends none, so the signed `application_username` and the
    // token in the StoreKit purchase options must be the same value. StoreKitTest rejects the
    // stub signature (StoreKitError.unknown), so the tests check the options the SDK passed to
    // `Product.purchase`, not a transaction. The hosted user id is not a UUID, so the SDK falls
    // back to the installation id; each test sets the installation id it needs. An uppercase UUID
    // reproduces the client's value (NSUUID().uuidString).
    @MainActor
    private func purchasePromoOffer(deviceID: String, whileSigning: (() -> Void)? = nil) async throws -> (signed: String?, options: Set<Product.PurchaseOption>) {
        let session = try XCTUnwrap(Self.storeKitSession)
        session.clearTransactions()
        defer { session.clearTransactions() }

        await startSDKIfNeeded()
        let deadline = Date().addingTimeInterval(15)
        while ApphudStoreKitWrapper.shared.appropriateApplicationUsername() == nil && Date() < deadline {
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        XCTAssertNotNil(ApphudStoreKitWrapper.shared.appropriateApplicationUsername(), "the payment queue must be swizzled")
        XCTAssertNil(UUID(uuidString: ApphudInternal.shared.currentUserID), "precondition: the hosted user id is not a UUID")

        let originalDeviceID = ApphudInternal.shared.currentInstallationID
        defer { ApphudInternal.shared.currentInstallationID = originalDeviceID }
        ApphudInternal.shared.currentInstallationID = deviceID
        ApphudAsyncStoreKit.shared.lastPurchaseOptions = []
        ApphudStubURLProtocol.reset()

        let purchase = Task { @MainActor in
            await withCheckedContinuation { continuation in
                ApphudInternal.shared.purchasePromo(productId: "com.apphud.monthly_promo", apphudProduct: nil,
                                                    discountID: "com.apphud.monthly_promo_skidos", fromScreen: false) { _ in
                    continuation.resume()
                }
            }
        }
        if let whileSigning {
            let signDeadline = Date().addingTimeInterval(10)
            while ApphudStubURLProtocol.requests(to: "/sign_offer").isEmpty && Date() < signDeadline {
                try await Task.sleep(nanoseconds: 50_000_000)
            }
            whileSigning()
        }
        await purchase.value

        let sign = try XCTUnwrap(ApphudStubURLProtocol.requests(to: "/sign_offer").last, "no /sign_offer request")
        return (sign.body["application_username"] as? String, ApphudAsyncStoreKit.shared.lastPurchaseOptions)
    }

    private let signedUUID = UUID(uuidString: "2F8AE6A1-B7C5-4966-8DF8-89F750012506")!

    /// The appAccountToken values in purchase options, lowercase. `Product.PurchaseOption`
    /// equality ignores the value (`.appAccountToken(a) == .appAccountToken(b)`), so the
    /// tokens are read from the options' descriptions: `"appAccountToken": "<uuid>"`.
    private func appAccountTokens(in options: Set<Product.PurchaseOption>) -> [String] {
        let prefix = "\"appAccountToken\": \""
        return options.map { String(reflecting: $0) }.filter { $0.hasPrefix(prefix) }.map { String($0.dropFirst(prefix.count).dropLast()) }
    }

    @MainActor
    func test8PromoOfferPurchaseSendsTheSignedUUIDToken() async throws {
        let (signed, options) = try await purchasePromoOffer(deviceID: signedUUID.uuidString)

        XCTAssertEqual(signed, "2f8ae6a1-b7c5-4966-8df8-89f750012506", "Apple checks the token in lowercase")
        XCTAssertEqual(appAccountTokens(in: options), [signed], "the purchase must send the signed token")
        XCTAssertEqual(options.count, 2, "the promotional offer and the token")
    }

    // MARK: 8b. A non-UUID id: the purchase sends no token, so the empty string is signed

    @MainActor
    func test8bPromoOfferWithNonUUIDIdSignsEmptyString() async throws {
        let (signed, options) = try await purchasePromoOffer(deviceID: "Custom-Device-42")

        XCTAssertEqual(signed, "", "with no appAccountToken on the purchase Apple checks an empty string")
        XCTAssertEqual(appAccountTokens(in: options), [], "no token on the purchase")
        XCTAssertEqual(options.count, 1, "only the promotional offer")
    }

    // MARK: 8c. An id change while the offer is being signed does not change the purchase token

    @MainActor
    func test8cPromoOfferTokenIsReadOnceForSignatureAndPurchase() async throws {
        let changedUUID = UUID(uuidString: "7C1D0E52-9B3A-4F6E-A2D8-5E4B3C2A1F90")!
        ApphudStubURLProtocol.signOfferResponseDelay = 1
        let (signed, options) = try await purchasePromoOffer(deviceID: signedUUID.uuidString) {
            ApphudInternal.shared.currentInstallationID = changedUUID.uuidString
        }

        XCTAssertEqual(signed, "2f8ae6a1-b7c5-4966-8df8-89f750012506")
        XCTAssertEqual(appAccountTokens(in: options), [signed], "the purchase must send the token that was signed")
        XCTAssertEqual(options.count, 2, "the promotional offer and the token")
    }

    // MARK: 8d. A token that appears while the offer is being signed is not added to the purchase

    // The offer is signed with no token (the ids are not UUIDs), then a token becomes available
    // before the purchase starts.
    // Not a duplicate of 8c: only this test fails if the promo purchase lets `purchaseResult` add
    // the current token, because Set<Product.PurchaseOption> keeps an already present token.
    @MainActor
    func test8dPromoOfferSignedWithoutTokenIsPurchasedWithoutToken() async throws {
        ApphudStubURLProtocol.signOfferResponseDelay = 1
        let (signed, options) = try await purchasePromoOffer(deviceID: "Custom-Device-42") {
            ApphudInternal.shared.currentInstallationID = "7C1D0E52-9B3A-4F6E-A2D8-5E4B3C2A1F90"
        }

        XCTAssertEqual(signed, "")
        XCTAssertEqual(appAccountTokens(in: options), [], "the purchase must not send a token the offer was not signed for")
        XCTAssertEqual(options.count, 1, "only the promotional offer")
    }

    // MARK: 7. Restore returns control when registration can never succeed

    // Like the purchase path, a restore must not wait forever for a user registration
    // that will never be retried (invalid API key / unauthorized): the app's restore UI
    // would hang. The entitlement bought below makes the restore reach the registration
    // wait — with no entitlement and no receipt it returns early on its own.
    @MainActor
    func test7RestoreDoesNotHangWhenRegistrationCannotSucceed() async throws {
        let session = try XCTUnwrap(Self.storeKitSession)
        session.clearTransactions()
        defer { session.clearTransactions() }

        await startSDKIfNeeded()
        ApphudInternal.shared.lastUploadedTransactions = []

        try session.buyProduct(productIdentifier: ApphudTestConstants.weeklyProductId)
        // Let the SDK's own background tracking of that purchase fully settle first.
        let settleDeadline = Date().addingTimeInterval(10)
        repeat {
            try await Task.sleep(nanoseconds: 300_000_000)
        } while (ApphudInternal.shared.submittingTransaction != nil || ApphudStubURLProtocol.requests(to: "/subscriptions").isEmpty) && Date() < settleDeadline
        ApphudStubURLProtocol.reset()

        let client = try XCTUnwrap(ApphudInternal.shared.httpClient)
        let registeredUser = ApphudInternal.shared.currentUser
        ApphudInternal.shared.currentUser = nil
        client.invalidAPiKey = true
        // Put the shared SDK back whatever happens below, so a failure here cannot poison later tests.
        defer {
            client.invalidAPiKey = false
            ApphudInternal.shared.currentUser = registeredUser
        }

        let restoreExpectation = XCTestExpectation(description: "restore completes although registration can never succeed")
        let restoreBox = ApphudResultBox()
        await MainActor.run {
            ApphudInternal.shared.restorePurchases { result in
                restoreBox.result = result
                restoreExpectation.fulfill()
            }
        }
        await fulfillment(of: [restoreExpectation], timeout: 10)

        let restore = try XCTUnwrap(restoreBox.result, "Restore must return control when registration can never succeed — a hang means its callback waits forever")
        XCTAssertNotNil(restore.error, "A restore without a registered user must report an error, not success")
        let submits = ApphudStubURLProtocol.requests(to: "/subscriptions").filter { $0.method == "POST" }
        XCTAssertEqual(submits.count, 0, "Nothing must be submitted without a registered user")
    }

    // MARK: 9. A StoreKit-level purchase failure returns control with an error

    /// Core-functionality contract: when the StoreKit layer cannot start the purchase,
    /// the callback must return an error — control goes back to the app, nothing
    /// hangs — and nothing may reach the backend. Exercised via an unknown product id:
    /// SKTestSession's failTransactionsEnabled cannot be used — on current simulator
    /// runtimes the flag sticks in storekitd forever (survives relaunches, ignores
    /// being set back to false) and poisons every later purchase until device erase.
    @MainActor
    func test9StoreKitFailureReturnsControlWithError() async throws {
        let session = try XCTUnwrap(Self.storeKitSession)
        session.clearTransactions()
        defer { session.clearTransactions() }

        await startSDKIfNeeded()
        ApphudInternal.shared.lastUploadedTransactions = []
        ApphudStubURLProtocol.reset()

        let result: ApphudPurchaseResult = await withCheckedContinuation { continuation in
            ApphudInternal.shared.purchase(productId: "com.apphud.nonexistent.product",
                                           product: nil,
                                           validate: true,
                                           purchasingFromScreen: false) { result in
                continuation.resume(returning: result)
            }
        }

        XCTAssertNotNil(result.error, "A purchase StoreKit cannot start must return an error to the app")
        XCTAssertFalse(result.success, "A failed purchase must not be reported as success")
        let submits = ApphudStubURLProtocol.requests(to: "/subscriptions").filter { $0.method == "POST" }
        XCTAssertEqual(submits.count, 0, "Nothing must be submitted to the backend when the purchase never started")
    }

    // MARK: 2. Purchase pipeline baseline

    @MainActor
    func test2PurchaseSubmitsReceiptToBackend() async throws {
        let session = try XCTUnwrap(Self.storeKitSession)
        session.clearTransactions()

        await startSDKIfNeeded()
        ApphudStubURLProtocol.reset()
        // clearTransactions() resets StoreKitTest's transaction id counter while the
        // SDK's dedup list persists in UserDefaults between test-host launches.
        ApphudInternal.shared.lastUploadedTransactions = []

        let result: ApphudPurchaseResult = await withCheckedContinuation { continuation in
            ApphudInternal.shared.purchase(productId: ApphudTestConstants.weeklyProductId,
                                           product: nil,
                                           validate: true,
                                           purchasingFromScreen: false) { result in
                continuation.resume(returning: result)
            }
        }

        XCTAssertNil(result.error, "Purchase must succeed against SKTestSession, got: \(String(describing: result.error))")
        XCTAssertEqual(result.subscription?.productId, ApphudTestConstants.weeklyProductId)

        let submits = ApphudStubURLProtocol.requests(to: "/subscriptions").filter { $0.method == "POST" }
        XCTAssertEqual(submits.count, 1, "Exactly one receipt submission expected")

        guard let body = submits.first?.body else {
            XCTFail("No subscription submission captured")
            return
        }
        // Payload contract (StoreKit 2 pipeline): receipt still attached while
        // readable, plus the SK2 transaction id and its signed JWS representation.
        // Values are pinned against the actual StoreKit transaction — a wrong id or
        // garbage JWS must fail, not just a missing field.
        // The receipt is attached only when the App Store put one on the device —
        // fresh simulators have none, and the payload then rides on transaction_id
        // + jws (pinned below). Assert consistency with the device, not presence.
        if apphudReceiptDataString() != nil {
            XCTAssertNotNil(body["receipt_data"] as? String, "App Store receipt must be attached while readable")
        }
        let latestResult = await StoreKit.Transaction.latest(for: ApphudTestConstants.weeklyProductId)
        let latest = try XCTUnwrap(latestResult, "StoreKitTest must hold a transaction for the purchased product")
        guard case .verified(let latestTrx) = latest else { return XCTFail("Purchased transaction must be verified") }
        XCTAssertEqual(body["transaction_id"] as? String, String(latestTrx.id),
                       "transaction id must match the purchased StoreKit transaction")
        // StoreKitTest re-signs the JWS on every query (fresh signedDate/nonce), so the
        // string itself is not comparable — the signed PAYLOAD's identity fields are.
        let jwsPayload = try XCTUnwrap(Self.jwsPayloadJSON(body["jws"] as? String),
                                       "jws must be a decodable signed transaction")
        XCTAssertEqual(jwsPayload["transactionId"] as? String, String(latestTrx.id),
                       "jws must be signed for the purchased transaction")
        XCTAssertEqual(jwsPayload["productId"] as? String, ApphudTestConstants.weeklyProductId,
                       "jws must be signed for the purchased product")
        XCTAssertEqual(body["observer_mode"] as? Bool, false)
        XCTAssertEqual(body["environment"] as? String, "sandbox")
        XCTAssertEqual((body["product_info"] as? [String: Any])?["product_id"] as? String, ApphudTestConstants.weeklyProductId)
        XCTAssertNotNil(body["installation_id"] as? String)
        XCTAssertNotNil(body["anonymous_id"] as? String)
        XCTAssertNil(body["device_id"], "the new shape never sends device_id")
        XCTAssertEqual(body["user_id"] as? String, ApphudTestConstants.userId)
        XCTAssertEqual(body["restore"] as? Bool, false, "a purchase never takes a subscription from another customer")
    }

    // MARK: 3. Foreign (observer-mode) purchase tracking baseline

    @MainActor
    func test3ForeignPurchaseIsTracked() async throws {
        let session = try XCTUnwrap(Self.storeKitSession)
        session.clearTransactions()
        // Untracked foreign transactions stay unfinished in observer mode — drop them
        // so they don't leak into the next test run.
        defer { session.clearTransactions() }

        await startSDKIfNeeded()
        ApphudStubURLProtocol.reset()
        // clearTransactions() resets StoreKitTest's transaction id counter, so ids from
        // previous tests would be deduplicated by the SDK — reset the dedup state too.
        ApphudInternal.shared.lastUploadedTransactions = []

        // Purchase made outside of the SDK — the payment queue observer must pick it up.
        try session.buyProduct(productIdentifier: "com.apphud.lifetime")

        let deadline = Date().addingTimeInterval(30)
        var tracked: [ApphudStubURLProtocol.RecordedRequest] = []
        while Date() < deadline {
            tracked = ApphudStubURLProtocol.requests(to: "/subscriptions").filter { $0.method == "POST" }
            if !tracked.isEmpty { break }
            try await Task.sleep(nanoseconds: 200_000_000)
        }

        XCTAssertFalse(tracked.isEmpty, "Foreign purchase must be auto-tracked via POST /v4/subscriptions")
        XCTAssertNotNil(tracked.last?.body["receipt_data"] as? String)
        XCTAssertEqual(tracked.last?.body["restore"] as? Bool, false, "automatic tracking is no restore")
    }

    // MARK: 3b. Concurrent delivery of one transaction must upload it once

    /// The same transaction reaches the SDK twice — from the purchase call and from the
    /// `Transaction.updates` listener. Only one submission may go out, and the second
    /// caller must receive the same outcome instead of a premature "nothing happened".
    @MainActor
    func test3bConcurrentDeliveryUploadsTransactionOnce() async throws {
        let session = try XCTUnwrap(Self.storeKitSession)
        session.clearTransactions()
        defer { session.clearTransactions() }

        await startSDKIfNeeded()
        ApphudInternal.shared.lastUploadedTransactions = []

        try session.buyProduct(productIdentifier: "com.apphud.lifetime")

        // Grab the resulting verified transaction without letting the SDK submit it yet.
        var delivered: VerificationResult<StoreKit.Transaction>?
        let deadline = Date().addingTimeInterval(10)
        while Date() < deadline && delivered == nil {
            for await result in StoreKit.Transaction.all {
                if case .verified(let trx) = result, trx.productID == "com.apphud.lifetime" {
                    delivered = result
                    break
                }
            }
            if delivered == nil { try await Task.sleep(nanoseconds: 200_000_000) }
        }
        let verified = try XCTUnwrap(delivered, "SKTestSession must produce a verified transaction")

        ApphudStubURLProtocol.reset()
        ApphudInternal.shared.lastUploadedTransactions = []
        // Keep the first submission in flight while the duplicate arrives.
        ApphudStubURLProtocol.subscriptionsResponseDelay = 1.0

        async let first = ApphudAsyncStoreKit.processTransaction(verified.unsafePayloadValue, jws: verified.jwsRepresentation)
        async let second = ApphudAsyncStoreKit.processTransaction(verified.unsafePayloadValue, jws: verified.jwsRepresentation)
        let results = await [first, second]

        let submits = ApphudStubURLProtocol.requests(to: "/subscriptions").filter { $0.method == "POST" }
        XCTAssertEqual(submits.count, 1, "A transaction delivered twice must be uploaded exactly once")
        XCTAssertEqual(results[0] == nil, results[1] == nil, "Both callers must observe the same outcome")
        XCTAssertNil(results[0], "The submission succeeded, so the transaction may be finished")
    }

    // MARK: 3c. A failed upload must not mark the transaction as delivered

    /// The dedup list is what authorises finishing a transaction, so a submission that
    /// the backend rejected must leave no trace in it — otherwise the transaction is
    /// finished on the next delivery and the paid purchase never reaches Apphud.
    @MainActor
    func test3cFailedUploadDoesNotMarkTransactionAsUploaded() async throws {
        let session = try XCTUnwrap(Self.storeKitSession)
        session.clearTransactions()
        defer { session.clearTransactions() }

        await startSDKIfNeeded()
        ApphudInternal.shared.lastUploadedTransactions = []
        ApphudStubURLProtocol.reset()
        ApphudStubURLProtocol.subscriptionsFailureStatus = 500

        let result: ApphudPurchaseResult = await withCheckedContinuation { continuation in
            ApphudInternal.shared.purchase(productId: ApphudTestConstants.weeklyProductId,
                                           product: nil,
                                           validate: true,
                                           purchasingFromScreen: false) { result in
                continuation.resume(returning: result)
            }
        }

        let submits = ApphudStubURLProtocol.requests(to: "/subscriptions").filter { $0.method == "POST" }
        XCTAssertFalse(submits.isEmpty, "The SDK must have attempted an upload")

        // XCTUnwrap, not if-let: a failed id extraction must fail the test, or the
        // core assertion below would be silently skipped.
        let transactionId = try XCTUnwrap(
            submits.compactMap { $0.body["transaction_id"] as? String }.compactMap { UInt64($0) }.first,
            "The upload attempt must carry a transaction id")
        let uploaded = ApphudInternal.shared.lastUploadedTransactions
        XCTAssertFalse(uploaded.contains(transactionId),
                       "A transaction whose upload failed must not be recorded as uploaded")
        XCTAssertFalse(result.success, "A rejected submission must not be reported as a successful purchase")
        // Master parity: the purchase callback must surface the submission failure —
        // clients gating on `result.error == nil` would otherwise unlock without a
        // validated purchase (found live: the backend rejected the transaction and
        // the callback returned a nil error).
        XCTAssertNotNil(result.error,
                        "A purchase whose backend submission failed must return an error to the app")
    }

    // MARK: 3d. A failed upload must be recoverable on redelivery

    /// Completes the negative path of test3c: after the backend rejected the upload, the
    /// transaction is still unfinished — redelivering it once the backend is healthy must
    /// upload it and only then mark it as delivered.
    @MainActor
    func test3dFailedUploadIsRecoveredOnRedelivery() async throws {
        let session = try XCTUnwrap(Self.storeKitSession)
        session.clearTransactions()
        defer { session.clearTransactions() }

        await startSDKIfNeeded()
        ApphudInternal.shared.lastUploadedTransactions = []
        ApphudStubURLProtocol.reset()
        ApphudStubURLProtocol.subscriptionsFailureStatus = 500

        _ = await withCheckedContinuation { continuation in
            ApphudInternal.shared.purchase(productId: ApphudTestConstants.weeklyProductId,
                                           product: nil,
                                           validate: true,
                                           purchasingFromScreen: false) { result in
                continuation.resume(returning: result)
            }
        }
        XCTAssertTrue(ApphudInternal.shared.lastUploadedTransactions.isEmpty, "Failed upload must leave no delivered mark")

        // Backend is healthy again; the unfinished transaction gets redelivered.
        ApphudStubURLProtocol.subscriptionsFailureStatus = nil
        ApphudStubURLProtocol.reset()

        // Transaction.unfinished (not .all): proves the failed transaction was NOT
        // finished — Transaction.all would also return finished ones.
        var redelivered: VerificationResult<StoreKit.Transaction>?
        for await result in StoreKit.Transaction.unfinished {
            if case .verified(let trx) = result, trx.productID == ApphudTestConstants.weeklyProductId {
                redelivered = result
                break
            }
        }
        let verified = try XCTUnwrap(redelivered, "The failed transaction must still be UNFINISHED")

        let submitError = await ApphudAsyncStoreKit.processTransaction(verified.unsafePayloadValue, jws: verified.jwsRepresentation)

        XCTAssertNil(submitError, "Redelivery against a healthy backend must succeed")
        let submits = ApphudStubURLProtocol.requests(to: "/subscriptions").filter { $0.method == "POST" }
        XCTAssertEqual(submits.count, 1, "Redelivery must upload the transaction")
        XCTAssertTrue(ApphudInternal.shared.lastUploadedTransactions.contains(verified.unsafePayloadValue.id),
                      "A successful upload must record the transaction as delivered")
    }

    // MARK: 2b. A purchase carries the user's token, and the install remembers who bought

    @MainActor
    func test2bPurchaseOfAUUIDUserCarriesAndRemembersItsToken() async throws {
        let session = try XCTUnwrap(Self.storeKitSession)
        session.clearTransactions()
        defer { session.clearTransactions() }
        await startSDKIfNeeded()
        ApphudStubURLProtocol.reset()
        ApphudInternal.shared.lastUploadedTransactions = []

        let user = UUID()
        let tokensKey = ApphudStoreKitWrapper.purchaseUserTokensKey
        let saved = ApphudInternal.shared.identity
        UserDefaults.standard.removeObject(forKey: tokensKey)
        defer {
            ApphudInternal.shared.identity = saved
            UserDefaults.standard.removeObject(forKey: tokensKey)
        }
        ApphudInternal.shared.identity.userID = user.uuidString

        let result: ApphudPurchaseResult = await withCheckedContinuation { continuation in
            ApphudInternal.shared.purchase(productId: ApphudTestConstants.weeklyProductId, product: nil, validate: true,
                                           purchasingFromScreen: false) { result in
                continuation.resume(returning: result)
            }
        }

        XCTAssertNil(result.error)
        let latestResult = await StoreKit.Transaction.latest(for: ApphudTestConstants.weeklyProductId)
        guard case .verified(let transaction) = try XCTUnwrap(latestResult) else { return XCTFail("verified transaction expected") }
        XCTAssertEqual(transaction.appAccountToken, user, "the purchase carries the user's token")
        XCTAssertEqual(ApphudStoreKitWrapper.purchaseUserTokens(), [user], "the install remembers who bought")
    }

    // MARK: 3e. Automatic paths skip another account's transaction; a restore sends it

    /// Alice bought through the SDK on this install, so her UUID user id is the purchase's token;
    /// someone else is current now. The legacy queue twin, the updates listener and the launch
    /// check leave her transaction alone and unfinished; the restore the user asks for submits it.
    @MainActor
    func test3eAutomaticPathsSkipAnotherAccountsTransaction() async throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("buyProduct(identifier:options:) needs iOS 17") }
        let session = try XCTUnwrap(Self.storeKitSession)
        session.clearTransactions()
        defer { session.clearTransactions() }
        await startSDKIfNeeded()

        let alice = UUID()
        let tokensKey = ApphudStoreKitWrapper.purchaseUserTokensKey
        UserDefaults.standard.removeObject(forKey: tokensKey)
        defer { UserDefaults.standard.removeObject(forKey: tokensKey) }
        var aliceIdentity = ApphudInternal.shared.identity
        aliceIdentity.userID = alice.uuidString
        ApphudStoreKitWrapper.rememberPurchaseToken(alice, identity: aliceIdentity)
        ApphudStubURLProtocol.reset()
        ApphudInternal.shared.lastUploadedTransactions = []

        func submissions(after seconds: UInt64) async throws -> Int {
            try await Task.sleep(nanoseconds: seconds * 1_000_000_000)
            return ApphudStubURLProtocol.requests(to: "/subscriptions").filter { $0.method == "POST" }.count
        }

        // Bought outside the SDK: observer mode, the legacy queue twin and the updates listener.
        let transaction = try await session.buyProduct(identifier: "com.apphud.lifetime", options: [.appAccountToken(alice)])
        let observed = try await submissions(after: 8)
        XCTAssertEqual(observed, 0, "the legacy queue twin and the updates listener submit nothing for another account")

        // The updates listener of an SDK that finishes transactions, and the launch check.
        let latestResult = await StoreKit.Transaction.latest(for: "com.apphud.lifetime")
        let latest = try XCTUnwrap(latestResult)
        ApphudUtils.shared.storeKitObserverMode = false
        ApphudAsyncStoreKit.shared.transactionsListener.handle(updatedTransaction: latest)
        ApphudInternal.shared.checkTransactionsNow()
        let checked = try await submissions(after: 4)
        XCTAssertEqual(checked, 0, "the updates listener and the launch check submit nothing for another account")
        var unfinished = false
        for await result in StoreKit.Transaction.unfinished where result.unsafePayloadValue.id == transaction.id {
            unfinished = true
        }
        XCTAssertTrue(unfinished, "left unfinished for its owner: the backend may not have it yet")

        // The restore the user asked for.
        let result: ApphudPurchaseResult = await withCheckedContinuation { continuation in
            Task { @MainActor in
                ApphudInternal.shared.restorePurchases { result in
                    continuation.resume(returning: result)
                }
            }
        }
        XCTAssertNil(result.error)
        let submits = ApphudStubURLProtocol.requests(to: "/subscriptions").filter { $0.method == "POST" }
        XCTAssertEqual(submits.count, 1)
        XCTAssertEqual(submits.last?.body["transaction_id"] as? String, String(transaction.id))
        XCTAssertEqual(submits.last?.body["restore"] as? Bool, true, "moves only with the restore")
    }

    // MARK: 3f. Once someone with a UUID id bought here, a purchase of nobody's account is still tracked

    @MainActor
    func test3fForeignPurchaseIsTrackedOnceAUUIDUserBoughtHere() async throws {
        let session = try XCTUnwrap(Self.storeKitSession)
        session.clearTransactions()
        defer { session.clearTransactions() }
        await startSDKIfNeeded()

        let tokensKey = ApphudStoreKitWrapper.purchaseUserTokensKey
        let alice = UUID()
        var aliceIdentity = ApphudInternal.shared.identity
        aliceIdentity.userID = alice.uuidString
        UserDefaults.standard.removeObject(forKey: tokensKey)
        defer { UserDefaults.standard.removeObject(forKey: tokensKey) }
        ApphudStoreKitWrapper.rememberPurchaseToken(alice, identity: aliceIdentity)
        ApphudStubURLProtocol.reset()
        ApphudInternal.shared.lastUploadedTransactions = []
        // Only the legacy queue twin's submission tells the delegate about an observed purchase.
        let observer = ObservedPurchases()
        let savedDelegate = ApphudInternal.shared.delegate
        ApphudInternal.shared.delegate = observer
        defer { ApphudInternal.shared.delegate = savedDelegate }

        try session.buyProduct(productIdentifier: "com.apphud.lifetime")

        let deadline = Date().addingTimeInterval(30)
        while observer.count == 0 && Date() < deadline {
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        XCTAssertGreaterThan(observer.count, 0, "the legacy queue twin of a purchase without a token is submitted")
        let tracked = ApphudStubURLProtocol.requests(to: "/subscriptions").filter { $0.method == "POST" }
        XCTAssertFalse(tracked.isEmpty)
        XCTAssertEqual(tracked.last?.body["restore"] as? Bool, false)
    }

    private final class ObservedPurchases: ApphudDelegate {
        var count = 0
        func apphudDidObservePurchase(result: ApphudPurchaseResult) -> Bool {
            count += 1
            return false
        }
    }

    // MARK: 3g. Another account's renewal is finished; its first purchase waits for the owner

    @MainActor
    func test3gAnotherAccountsRenewalIsFinishedItsPurchaseKept() async throws {
        guard #available(iOS 17.0, *) else { throw XCTSkip("buyProduct(identifier:options:) needs iOS 17") }
        let session = try XCTUnwrap(Self.storeKitSession)
        session.clearTransactions()
        defer { session.clearTransactions() }
        await startSDKIfNeeded()

        let tokensKey = ApphudStoreKitWrapper.purchaseUserTokensKey
        let alice = UUID()
        var aliceIdentity = ApphudInternal.shared.identity
        aliceIdentity.userID = alice.uuidString
        UserDefaults.standard.removeObject(forKey: tokensKey)
        defer { UserDefaults.standard.removeObject(forKey: tokensKey) }
        ApphudStoreKitWrapper.rememberPurchaseToken(alice, identity: aliceIdentity)

        let purchase = try await session.buyProduct(identifier: ApphudTestConstants.weeklyProductId, options: [.appAccountToken(alice)])
        try session.forceRenewalOfSubscription(productIdentifier: ApphudTestConstants.weeklyProductId)
        let deadline = Date().addingTimeInterval(10)
        var renewal: StoreKit.Transaction?
        while renewal == nil && Date() < deadline {
            if case .verified(let latest) = await StoreKit.Transaction.latest(for: ApphudTestConstants.weeklyProductId),
               latest.id != purchase.id {
                renewal = latest
            }
            try await Task.sleep(nanoseconds: 200_000_000)
        }
        let renewed = try XCTUnwrap(renewal, "StoreKitTest renews the subscription")
        XCTAssertEqual(renewed.appAccountToken, alice, "a renewal keeps the purchase's token")
        try await Task.sleep(nanoseconds: 3_000_000_000)
        ApphudStubURLProtocol.reset()
        ApphudInternal.shared.lastUploadedTransactions = []

        let renewalResult = await ApphudInternal.shared.handleTransactionResult(renewed, automatic: true)
        let purchaseResult = await ApphudInternal.shared.handleTransactionResult(purchase, automatic: true)

        XCTAssertNil(renewalResult, "a renewal of another account's subscription may be finished")
        XCTAssertNotNil(purchaseResult, "another account's purchase waits unfinished for its owner")
        XCTAssertEqual(ApphudStubURLProtocol.requests(to: "/subscriptions").filter { $0.method == "POST" }.count, 0)

        // The legacy queue twin finds both, also the older one once something finished it.
        await purchase.finish()
        var stillUnfinished = false
        for await result in StoreKit.Transaction.unfinished where result.unsafePayloadValue.id == purchase.id {
            stillUnfinished = true
        }
        XCTAssertFalse(stillUnfinished, "precondition: the first purchase is finished")
        let weekly = ApphudTestConstants.weeklyProductId
        let renewalOwner = await ApphudInternal.shared.anotherAccountsTransaction(id: renewed.id, productID: weekly)
        let purchaseOwner = await ApphudInternal.shared.anotherAccountsTransaction(id: purchase.id, productID: weekly)
        let unknown = await ApphudInternal.shared.anotherAccountsTransaction(id: renewed.id + 1000, productID: weekly)
        XCTAssertEqual(renewalOwner?.id, renewed.id)
        XCTAssertEqual(purchaseOwner?.id, purchase.id, "a finished transaction older than the latest one")
        XCTAssertNil(unknown)

        let saved = ApphudInternal.shared.identity
        defer { ApphudInternal.shared.identity = saved }
        ApphudInternal.shared.identity = aliceIdentity
        let alicesOwn = await ApphudInternal.shared.anotherAccountsTransaction(id: purchase.id, productID: weekly)
        let alicesOwnRenewal = await ApphudInternal.shared.anotherAccountsTransaction(id: renewed.id, productID: weekly)
        XCTAssertNil(alicesOwn, "alice's own transaction while she is current")
        XCTAssertNil(alicesOwnRenewal, "alice's own latest transaction while she is current")
    }

    // MARK: 5. Restore submits the newest entitlement

    @MainActor
    func test5RestoreSubmitsEntitlementWithJws() async throws {
        let session = try XCTUnwrap(Self.storeKitSession)
        session.clearTransactions()
        defer { session.clearTransactions() }

        await startSDKIfNeeded()
        ApphudInternal.shared.lastUploadedTransactions = []

        // Give the device an entitlement outside of the SDK flow, and let the SDK's own
        // background tracking of it fully finish — otherwise the restore below would
        // piggyback on that in-flight submission instead of making its own.
        try session.buyProduct(productIdentifier: ApphudTestConstants.weeklyProductId)
        let settleDeadline = Date().addingTimeInterval(10)
        repeat {
            try await Task.sleep(nanoseconds: 300_000_000)
        } while (ApphudInternal.shared.submittingTransaction != nil || ApphudStubURLProtocol.requests(to: "/subscriptions").isEmpty) && Date() < settleDeadline
        ApphudStubURLProtocol.reset()
        ApphudInternal.shared.lastUploadedTransactions = []

        let result: ApphudPurchaseResult = await withCheckedContinuation { continuation in
            Task { @MainActor in
                ApphudInternal.shared.restorePurchases { result in
                    continuation.resume(returning: result)
                }
            }
        }

        XCTAssertNil(result.error, "Restore with a valid entitlement must succeed, got: \(String(describing: result.error))")
        let submits = ApphudStubURLProtocol.requests(to: "/subscriptions").filter { $0.method == "POST" }
        XCTAssertEqual(submits.count, 1, "Restore must submit the entitlement exactly once")
        let body = try XCTUnwrap(submits.last?.body)
        // Pin the entitlement's actual values, not mere field presence.
        let entitlementResult = await StoreKit.Transaction.latest(for: ApphudTestConstants.weeklyProductId)
        let entitlement = try XCTUnwrap(entitlementResult, "StoreKitTest must hold the entitlement bought above")
        guard case .verified(let entitlementTrx) = entitlement else { return XCTFail("Entitlement must be verified") }
        XCTAssertEqual(body["transaction_id"] as? String, String(entitlementTrx.id),
                       "Restore must carry the entitlement's transaction id")
        // Same as test2: the JWS string is re-signed per query, compare payload identity.
        let jwsPayload = try XCTUnwrap(Self.jwsPayloadJSON(body["jws"] as? String),
                                       "Restore must carry a decodable signed transaction")
        XCTAssertEqual(jwsPayload["transactionId"] as? String, String(entitlementTrx.id),
                       "Restore's jws must be signed for the entitlement's transaction")
        XCTAssertEqual(body["restore"] as? Bool, true, "the restore the user asked for")
    }

    // MARK: 6. Restore piggybacks on an in-flight submission

    /// A restore that arrives while another submission is in flight must receive that
    /// submission's outcome — not an error and not an eternal wait.
    @MainActor
    func test6RestorePiggybacksOnInflightSubmission() async throws {
        let session = try XCTUnwrap(Self.storeKitSession)
        session.clearTransactions()
        defer { session.clearTransactions() }

        await startSDKIfNeeded()
        ApphudInternal.shared.lastUploadedTransactions = []
        ApphudStubURLProtocol.reset()
        ApphudStubURLProtocol.subscriptionsResponseDelay = 1.5

        // Start a purchase; its submission will be in flight for ~1.5s.
        let purchaseTask = Task { @MainActor () -> ApphudPurchaseResult in
            await withCheckedContinuation { continuation in
                ApphudInternal.shared.purchase(productId: ApphudTestConstants.weeklyProductId,
                                               product: nil,
                                               validate: true,
                                               purchasingFromScreen: false) { result in
                    continuation.resume(returning: result)
                }
            }
        }

        // Give the purchase time to reach the network layer, then restore mid-flight.
        try await Task.sleep(nanoseconds: 700_000_000)

        // Bounded wait via XCTestExpectation: the known failure mode of this path is a
        // dropped callback that never resolves — the test must FAIL on that (unfulfilled
        // expectation), not hang the whole run. Task-group timeouts don't work here:
        // the group would still await the non-cancellable continuation on exit.
        let restoreExpectation = XCTestExpectation(description: "restore completes while a submission is in flight")
        let restoreBox = ApphudResultBox()
        ApphudInternal.shared.restorePurchases { result in
            restoreBox.result = result
            restoreExpectation.fulfill()
        }

        await fulfillment(of: [restoreExpectation], timeout: 10)

        let purchaseResult = await purchaseTask.value

        XCTAssertNil(purchaseResult.error, "The purchase itself must succeed")
        let restore = try XCTUnwrap(restoreBox.result, "Restore must complete while a submission is in flight — a hang means its callback was dropped")
        XCTAssertNil(restore.error, "A restore during an in-flight submission must piggyback on its outcome, got: \(String(describing: restore.error))")

        // The piggyback itself: the restore must NOT have fired a second POST — both
        // callers share the one in-flight submission. Without this, two independent
        // stub-blessed submissions would also pass the error checks above.
        let submits = ApphudStubURLProtocol.requests(to: "/subscriptions").filter { $0.method == "POST" }
        XCTAssertEqual(submits.count, 1, "Restore arriving mid-submission must piggyback, not fire its own request")
    }

    // MARK: 4. Legacy transaction dedup storage is not trusted after upgrade

    /// Data-compat contract, inverted from 4.4.x: the pre-SK2 SDK persisted ids under
    /// "ApphudLastUploadedTransactions" BEFORE backend acknowledgment, so an inherited id
    /// may belong to a purchase that never reached Apphud. This SDK's store means
    /// "backend acknowledged — safe to finish", therefore it lives under its own key and
    /// legacy ids must never authorize finishing a transaction. (Transactions the old SDK
    /// did get acknowledged were also finished by it, so ignoring the legacy list cannot
    /// cause redelivery loops; a rare re-submission is deduplicated by the backend.)
    @MainActor
    func test4LegacyDedupStorageIsIgnoredAfterUpgrade() async throws {
        let legacyKey = "ApphudLastUploadedTransactions"
        let currentKey = "ApphudLastUploadedTransactionsSK2"
        let savedLegacy = UserDefaults.standard.array(forKey: legacyKey)
        let savedCurrent = UserDefaults.standard.array(forKey: currentKey)
        defer {
            UserDefaults.standard.set(savedLegacy, forKey: legacyKey)
            UserDefaults.standard.set(savedCurrent, forKey: currentKey)
        }

        let preAckLegacyIds: [UInt64] = [2_000_000_123_456_789, 42]
        UserDefaults.standard.set(preAckLegacyIds, forKey: legacyKey)
        UserDefaults.standard.removeObject(forKey: currentKey)
        for id in preAckLegacyIds {
            XCTAssertFalse(ApphudInternal.shared.lastUploadedTransactions.contains(id),
                           "Ids inherited from the pre-SK2 SDK must not authorize finishing a transaction")
        }

        // The store itself round-trips as a plain [UInt64] array under the SK2 key,
        // and the legacy key is left as-is for a possible SDK downgrade.
        ApphudInternal.shared.lastUploadedTransactions = [7, 8]
        XCTAssertEqual(UserDefaults.standard.array(forKey: currentKey) as? [UInt64], [7, 8],
                       "Ack list must persist as a plain [UInt64] array under the SK2 key")
        XCTAssertEqual(UserDefaults.standard.array(forKey: legacyKey) as? [UInt64], preAckLegacyIds,
                       "Legacy key must be left untouched")
    }
}

// MARK: - The system Keychain

/// The host app's Keychain, written by identity version 1's own code (as in SDK 4.6) and by a logout on
/// version 2. Unit tests of the package have no Keychain on a simulator.
final class ApphudKeychainVersionTests: XCTestCase {

    private struct NoInstallRecord: ApphudInstallRecordStoring {
        func read() -> ApphudInstallRecordRead { .missing }
        func write(_ record: ApphudInstallRecord) -> Bool { true }
    }

    private let keychain = ApphudSystemKeychain()
    private let suiteName = "ApphudKeychainVersionTests"

    override func setUp() {
        super.setUp()
        clear()
    }

    override func tearDown() {
        clear()
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func clear() {
        ApphudKeychainKey.allCases.forEach(keychain.delete)
        UserDefaults.standard.removeObject(forKey: ApphudKeychain.defaultsDeviceIdKey)
        UserDefaults.standard.removeObject(forKey: ApphudKeychain.defaultsUserIdKey)
    }

    private func protectionClass(_ key: ApphudKeychainKey) -> String? {
        let query: NSDictionary = [kSecClass: kSecClassGenericPassword, kSecAttrService: key.rawValue,
                                   kSecAttrAccount: "ApphudUser", kSecReturnAttributes: true,
                                   kSecMatchLimit: kSecMatchLimitOne]
        var result: AnyObject?
        guard SecItemCopyMatching(query, &result) == errSecSuccess else { return nil }
        return (result as? [String: Any])?[kSecAttrAccessible as String] as? String
    }

    private func logOutOnVersion2() throws {
        let defaults = try XCTUnwrap(UserDefaults(suiteName: suiteName))
        var identity = ApphudIdentity(installationID: "inst", anonymousID: "anon", userID: "alice@example.com", isReinstall: false)
        ApphudIdentityStore(defaults: defaults, keychain: keychain, installRecords: NoInstallRecord())
            .logout(anonymousID: nil, &identity)
    }

    @MainActor
    func testVersion1AfterAReinstallGetsNoIDsBackFromAVersion2Logout() throws {
        try XCTSkipUnless(ApphudKeychain.canUseKeychain, "the Keychain is locked")
        ApphudKeychain.saveDeviceID(deviceID: "OLD-DEVICE")
        ApphudKeychain.saveUserID(userID: "alice@example.com")
        XCTAssertEqual(keychain.read(.legacyDeviceID), .found("OLD-DEVICE"))

        try logOutOnVersion2()
        // A reinstall: UserDefaults are gone, the Keychain stays.
        UserDefaults.standard.removeObject(forKey: ApphudKeychain.defaultsDeviceIdKey)
        UserDefaults.standard.removeObject(forKey: ApphudKeychain.defaultsUserIdKey)

        XCTAssertEqual(keychain.read(.legacyDeviceID), .found(""), "blanked, as SDK 4.6's own logout does")
        XCTAssertNil(ApphudKeychain.loadDeviceID(), "version 1 makes a new device id")
        XCTAssertNil(ApphudKeychain.loadUserID())
    }

    @MainActor
    func testVersion1WritesItsKeychainItemsAgainAfterAVersion2Logout() throws {
        try XCTSkipUnless(ApphudKeychain.canUseKeychain, "the Keychain is locked")
        ApphudKeychain.saveDeviceID(deviceID: "OLD-DEVICE")
        ApphudKeychain.saveUserID(userID: "alice@example.com")
        try logOutOnVersion2()
        XCTAssertEqual(protectionClass(.legacyDeviceID), kSecAttrAccessibleAfterFirstUnlock as String, "the class of SDK 4.6")

        ApphudKeychain.saveDeviceID(deviceID: "NEW-DEVICE")
        ApphudKeychain.saveUserID(userID: "bob")

        XCTAssertEqual(keychain.read(.legacyDeviceID), .found("NEW-DEVICE"))
        XCTAssertEqual(keychain.read(.legacyUserID), .found("bob"))
    }

    func testTheReinstallKeyNeverTravelsToAnotherDevice() throws {
        try XCTSkipUnless(keychain.write(.reinstall, value: "1"), "the Keychain is locked")

        XCTAssertEqual(protectionClass(.reinstall), kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly as String)
    }
}
