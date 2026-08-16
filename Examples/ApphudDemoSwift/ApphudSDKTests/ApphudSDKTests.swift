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
//  the StoreKit 2 migration): what gets sent to POST /v1/subscriptions and what
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

    static func record(_ request: RecordedRequest) {
        lock.lock(); defer { lock.unlock() }
        _requests.append(request)
    }

    static func requests(to pathSuffix: String) -> [RecordedRequest] {
        requests.filter { $0.path.hasSuffix(pathSuffix) }
    }

    /// Artificial latency for POST /v1/subscriptions, so a test can keep a submission
    /// in flight and exercise concurrent delivery of the same transaction.
    static var subscriptionsResponseDelay: TimeInterval = 0

    /// When set, POST /v1/subscriptions answers with this status instead of 200, so the
    /// failure paths (where purchases are lost) are exercisable.
    static var subscriptionsFailureStatus: Int?

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

        let delay = isSubscriptions ? Self.subscriptionsResponseDelay : 0
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
        // Drop unfinished transactions left over from previous test runs BEFORE the
        // SDK starts and its Transaction.updates listener begins redelivering them.
        storeKitSession?.clearTransactions()
    }

    override func tearDown() {
        super.tearDown()
        // Tracking a foreign purchase force-enables observer mode process-wide; reset it
        // so test order (or running a single test) can't change what other tests observe.
        ApphudUtils.shared.storeKitObserverMode = false
        ApphudStubURLProtocol.subscriptionsResponseDelay = 0
        ApphudStubURLProtocol.subscriptionsFailureStatus = nil
    }

    @MainActor
    private func startSDKIfNeeded() async {
        guard !Self.sdkStarted else { return }
        Self.sdkStarted = true

        Apphud.enableDebugLogs()
        await withCheckedContinuation { continuation in
            Apphud.startManually(apiKey: ApphudTestConstants.apiKey,
                                 userID: ApphudTestConstants.userId,
                                 deviceID: ApphudTestConstants.userId) { _ in
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
        XCTAssertFalse(registrations.isEmpty, "SDK must register the user via POST /v1/customers")
        XCTAssertEqual(registrations.last?.method, "POST")
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

    // MARK: 9. A StoreKit-level purchase failure returns control with an error
    // (numbered LAST: SKTestSession applies failTransactionsEnabled asynchronously in
    // storekitd, so the injection can leak into a purchase that starts right after
    // this test — no purchase test may run behind it)

    /// Core-functionality contract: when StoreKit itself fails the purchase (payment
    /// declined, store outage), the purchase callback must return an error — control
    /// goes back to the app, nothing hangs — and nothing may reach the backend.
    @MainActor
    func test9StoreKitFailureReturnsControlWithError() async throws {
        let session = try XCTUnwrap(Self.storeKitSession)
        session.clearTransactions()
        defer {
            session.clearTransactions()
            session.failTransactionsEnabled = false
        }

        await startSDKIfNeeded()
        ApphudInternal.shared.lastUploadedTransactions = []
        ApphudStubURLProtocol.reset()

        session.failTransactionsEnabled = true
        session.failureError = .unknown

        let result: ApphudPurchaseResult = await withCheckedContinuation { continuation in
            ApphudInternal.shared.purchase(productId: ApphudTestConstants.weeklyProductId,
                                           product: nil,
                                           validate: true,
                                           purchasingFromScreen: false) { result in
                continuation.resume(returning: result)
            }
        }

        XCTAssertNotNil(result.error, "A StoreKit-failed purchase must return an error to the app")
        XCTAssertFalse(result.success, "A StoreKit-failed purchase must not be reported as success")
        let submits = ApphudStubURLProtocol.requests(to: "/subscriptions").filter { $0.method == "POST" }
        XCTAssertEqual(submits.count, 0, "Nothing must be submitted to the backend when StoreKit fails the purchase")
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
        XCTAssertNotNil(body["receipt_data"] as? String, "App Store receipt must be attached while readable")
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
        XCTAssertNotNil(body["device_id"] as? String)
        XCTAssertEqual(body["user_id"] as? String, ApphudTestConstants.userId)
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

        XCTAssertFalse(tracked.isEmpty, "Foreign purchase must be auto-tracked via POST /v1/subscriptions")
        XCTAssertNotNil(tracked.last?.body["receipt_data"] as? String)
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
        XCTAssertEqual(results[0], results[1], "Both callers must observe the same outcome")
        XCTAssertTrue(results[0], "The submission succeeded, so the transaction may be finished")
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

        let handled = await ApphudAsyncStoreKit.processTransaction(verified.unsafePayloadValue, jws: verified.jwsRepresentation)

        XCTAssertTrue(handled, "Redelivery against a healthy backend must succeed")
        let submits = ApphudStubURLProtocol.requests(to: "/subscriptions").filter { $0.method == "POST" }
        XCTAssertEqual(submits.count, 1, "Redelivery must upload the transaction")
        XCTAssertTrue(ApphudInternal.shared.lastUploadedTransactions.contains(verified.unsafePayloadValue.id),
                      "A successful upload must record the transaction as delivered")
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
