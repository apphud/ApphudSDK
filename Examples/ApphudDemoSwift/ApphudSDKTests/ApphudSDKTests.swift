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
            "paywalls": [[String: Any]](),
            "placements": [[String: Any]](),
            "total_devices_count": 1
        ]
        return ["data": ["results": user]]
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
        XCTAssertNotNil(body["receipt_data"] as? String, "App Store receipt must be attached while readable")
        XCTAssertNotNil(body["transaction_id"] as? String, "transaction id must be attached")
        XCTAssertNotNil(body["jws"] as? String, "signed StoreKit 2 transaction (JWS) must be attached")
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

        let transactionId = submits.compactMap { $0.body["transaction_id"] as? String }.compactMap { UInt64($0) }.first
        let uploaded = ApphudInternal.shared.lastUploadedTransactions
        if let transactionId {
            XCTAssertFalse(uploaded.contains(transactionId),
                           "A transaction whose upload failed must not be recorded as uploaded")
        }
        XCTAssertFalse(result.success, "A rejected submission must not be reported as a successful purchase")
    }

    // MARK: 4. Upgrade compatibility of the transaction dedup storage

    /// Data-compat contract: the dedup list keeps the same UserDefaults key and shape as
    /// 4.4.x. A rename or format change would make the SDK re-upload every transaction
    /// the previous version had already submitted.
    @MainActor
    func test4TransactionDedupStorageIsUpgradeCompatible() async throws {
        let key = "ApphudLastUploadedTransactions"
        let saved = UserDefaults.standard.array(forKey: key)
        defer { UserDefaults.standard.set(saved, forKey: key) }

        // Values written by a previous SDK version must be read back as-is.
        let legacyValues: [UInt64] = [2_000_000_123_456_789, 42]
        UserDefaults.standard.set(legacyValues, forKey: key)
        XCTAssertEqual(ApphudInternal.shared.lastUploadedTransactions, legacyValues,
                       "Transactions stored by a previous SDK version must still be recognized")

        // And values written now must stay readable in the same plain-array shape.
        ApphudInternal.shared.lastUploadedTransactions = [7, 8]
        XCTAssertEqual(UserDefaults.standard.array(forKey: key) as? [UInt64], [7, 8],
                       "Dedup list must stay a plain [UInt64] array under the same key")
    }
}
