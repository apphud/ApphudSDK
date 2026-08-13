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

        let json = Self.fixture(for: path, requestBody: body)
        let data = try! JSONSerialization.data(withJSONObject: json)
        let response = HTTPURLResponse(url: url, statusCode: 200, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!

        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data)
        client?.urlProtocolDidFinishLoading(self)
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

    override class func setUp() {
        super.setUp()
        // Must be installed BEFORE the first access to ApphudHttpClient.shared.
        let config = URLSessionConfiguration.ephemeral
        config.protocolClasses = [ApphudStubURLProtocol.self]
        ApphudHttpClient.testURLSessionConfiguration = config
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
        let session = try SKTestSession(configurationFileNamed: "StoreKit")
        session.disableDialogs = true
        session.clearTransactions()

        await startSDKIfNeeded()
        ApphudStubURLProtocol.reset()

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

        let body = submits[0].body
        // Baseline payload contract (SK1 pipeline).
        XCTAssertNotNil(body["receipt_data"] as? String, "SK receipt must be attached")
        XCTAssertNotNil(body["transaction_id"] as? String, "transaction id must be attached")
        XCTAssertEqual(body["observer_mode"] as? Bool, false)
        XCTAssertEqual(body["environment"] as? String, "sandbox")
        XCTAssertEqual((body["product_info"] as? [String: Any])?["product_id"] as? String, ApphudTestConstants.weeklyProductId)
        XCTAssertNotNil(body["device_id"] as? String)
        XCTAssertEqual(body["user_id"] as? String, ApphudTestConstants.userId)
    }

    // MARK: 3. Foreign (observer-mode) purchase tracking baseline

    @MainActor
    func test3ForeignPurchaseIsTracked() async throws {
        let session = try SKTestSession(configurationFileNamed: "StoreKit")
        session.disableDialogs = true
        session.clearTransactions()

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
}
