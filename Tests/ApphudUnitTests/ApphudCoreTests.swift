//
//  ApphudCoreTests.swift
//  ApphudUnitTests
//
//  Pure-logic unit tests that run via `swift test` without StoreKit or network.
//

import XCTest
@testable import ApphudSDK

final class ApphudErrorTests: XCTestCase {

    func testNetworkIssueDetectsOfflineCodes() {
        XCTAssertTrue(ApphudError(message: "offline", code: APPHUD_ERROR_NO_INTERNET).networkIssue())
        XCTAssertTrue(ApphudError(message: "offline", code: NSURLErrorNotConnectedToInternet).networkIssue())
        XCTAssertTrue(ApphudError(message: "offline", code: NSURLErrorCannotConnectToHost).networkIssue())
        XCTAssertTrue(ApphudError(message: "offline", code: NSURLErrorCannotFindHost).networkIssue())
    }

    func testNetworkIssueFalseForRegularErrors() {
        XCTAssertFalse(ApphudError(message: "no products", code: APPHUD_NO_PRODUCTS).networkIssue())
        XCTAssertFalse(ApphudError(message: "plain").networkIssue())
    }

    func testHttpErrorKeepsCodeAndAttempts() {
        let error = ApphudError(httpErrorCode: 503, attempts: 3)
        XCTAssertEqual(error.code, 503)
        XCTAssertEqual(error.attempts, 3)
    }
}

final class ApphudEndpointTests: XCTestCase {

    // Backend contract: paths of the endpoints the purchase flow depends on.
    func testPurchaseFlowEndpointPaths() {
        XCTAssertEqual(ApphudHttpClient.ApphudEndpoint.subscriptions.value, "subscriptions")
        XCTAssertEqual(ApphudHttpClient.ApphudEndpoint.signOffer.value, "sign_offer")
        XCTAssertEqual(ApphudHttpClient.ApphudEndpoint.receipt.value, "subscriptions/raw")
        XCTAssertEqual(ApphudHttpClient.ApphudEndpoint.customers.value, "customers")
        XCTAssertEqual(ApphudHttpClient.ApphudEndpoint.paywalls.value, "paywall_configs")
    }

    func testOnlyCriticalEndpointsTriggerHostFallback() {
        XCTAssertTrue(ApphudHttpClient.ApphudEndpoint.subscriptions.canTriggerHostFallback)
        XCTAssertTrue(ApphudHttpClient.ApphudEndpoint.customers.canTriggerHostFallback)
        XCTAssertTrue(ApphudHttpClient.ApphudEndpoint.attribution.canTriggerHostFallback)
        XCTAssertFalse(ApphudHttpClient.ApphudEndpoint.logs.canTriggerHostFallback)
        XCTAssertFalse(ApphudHttpClient.ApphudEndpoint.signOffer.canTriggerHostFallback)
    }
}

final class ApphudUserDefaultsCacheTests: XCTestCase {

    // Data-compat contract: dictionary caches are stored as a plain [String: String]
    // under the same key across SDK versions (4.4.x -> 4.5.0 upgrade path).
    func testDictionaryCacheRoundTrip() {
        let key = "apphud_unit_test_cache_key"
        defer { UserDefaults.standard.removeObject(forKey: key) }

        let payload = ["paywall_id": "pw_1", "placement_id": "pl_2"]
        apphudToUserDefaultsCache(dictionary: payload, key: key)

        XCTAssertEqual(apphudFromUserDefaultsCache(key: key), payload)
        // Stored representation stays a plain dictionary readable without decoding.
        XCTAssertEqual(UserDefaults.standard.dictionary(forKey: key) as? [String: String], payload)
    }

    func testMissingCacheKeyReturnsNil() {
        XCTAssertNil(apphudFromUserDefaultsCache(key: "apphud_unit_test_never_written"))
    }

    // SDK 4.3.0–4.7.1 persisted the deferred deep link page URL; 4.7.2+ removes it on start.
    func testLegacyConnectDomainUrlIsRemoved() {
        let suiteName = "ApphudLegacyConnectDomainUrlTests"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }

        XCTAssertEqual(ApphudInternal.legacyConnectDomainUrlKey, "ApphudConnectDomainUrl")
        defaults.set("https://connect.aphd.cc/void", forKey: ApphudInternal.legacyConnectDomainUrlKey)

        ApphudInternal.removeLegacyConnectDomainUrl(from: defaults)

        XCTAssertNil(defaults.object(forKey: ApphudInternal.legacyConnectDomainUrlKey))
    }
}

final class ApphudDeeplinkAttributionTests: XCTestCase {

    @MainActor
    private func waitUntil(_ condition: () -> Bool) async throws {
        let deadline = Date().addingTimeInterval(5)
        while !condition() && Date() < deadline {
            try await Task.sleep(nanoseconds: 10_000_000)
        }
    }

    // The deferred result comes right after registration, possibly before the app sets its handler.
    @MainActor
    func testDeferredResultWaitsForTheHandler() async throws {
        let sdk = ApphudInternal()
        var received: [(matchType: String?, kind: ApphudDeeplinkAttributionKind)] = []

        sdk.notifyDeeplinkAttribution(attribution: ["match_type": "deterministic"], kind: .deferred, url: nil)
        sdk.setDeeplinkAttributionHandler { attribution, kind, _ in received.append((attribution["match_type"] as? String, kind)) }
        XCTAssertTrue(received.isEmpty, "not from inside the setter call")
        XCTAssertNil(sdk.pendingDeferredDeeplinkAttribution)
        try await waitUntil { !received.isEmpty }

        sdk.setDeeplinkAttributionHandler { attribution, kind, _ in received.append((attribution["match_type"] as? String, kind)) }
        await Task.yield()

        XCTAssertEqual(received.count, 1, "delivered once")
        XCTAssertEqual(received.first?.matchType, "deterministic")
        XCTAssertEqual(received.first?.kind, .deferred)
    }

    @MainActor
    func testEmptyResultDoesNotReplaceAPendingMatch() async throws {
        let sdk = ApphudInternal()
        var received: [[String: Any]] = []

        sdk.notifyDeeplinkAttribution(attribution: ["match_type": "deterministic"], kind: .deferred, url: nil)
        sdk.notifyDeeplinkAttribution(attribution: [:], kind: .deferred, url: nil)
        sdk.setDeeplinkAttributionHandler { attribution, _, _ in received.append(attribution) }
        try await waitUntil { !received.isEmpty }

        XCTAssertEqual(received.first?["match_type"] as? String, "deterministic")
    }

    @MainActor
    func testDirectResultIsNotKeptWithoutAHandler() {
        let sdk = ApphudInternal()

        sdk.notifyDeeplinkAttribution(attribution: ["match_type": "direct"], kind: .direct, url: URL(string: "https://example.com"))

        XCTAssertNil(sdk.pendingDeferredDeeplinkAttribution)
    }

    @MainActor
    func testDeferredRequestWhileOneIsInFlightIsIgnored() async throws {
        let sdk = ApphudInternal()

        sdk.requestDeferredDeeplinkAttribution()
        let first = sdk.deferredDeeplinkRequestID
        sdk.requestDeferredDeeplinkAttribution()

        XCTAssertNotNil(first)
        XCTAssertEqual(sdk.deferredDeeplinkRequestID, first, "the second call returns before starting a request")
        try await waitUntil { sdk.pendingUserRegistrationCallbackCount > 0 }
        XCTAssertEqual(sdk.pendingUserRegistrationCallbackCount, 1, "one request waits for registration")
    }

    @MainActor
    func testFinishedRequestDeliversAndAllowsTheNextOne() {
        let sdk = ApphudInternal()
        var received: [String?] = []
        sdk.setDeeplinkAttributionHandler { attribution, _, _ in received.append(attribution["match_type"] as? String) }
        let requestID = UUID()
        sdk.deferredDeeplinkRequestID = requestID

        sdk.finishDeferredDeeplinkRequest(requestID, attribution: ["match_type": "deterministic"])

        XCTAssertEqual(received, ["deterministic"])
        XCTAssertNil(sdk.deferredDeeplinkRequestID)
    }

    // A response that arrives after logout belongs to the old user: dropped, and the new request stays in flight.
    @MainActor
    func testResponseAfterLogoutIsDropped() {
        let sdk = ApphudInternal()
        var calls = 0
        sdk.setDeeplinkAttributionHandler { _, _, _ in calls += 1 }
        let oldRequest = UUID()
        sdk.deferredDeeplinkRequestID = oldRequest
        sdk.pendingDeferredDeeplinkAttribution = ["match_type": "deterministic"]

        sdk.resetDeferredDeeplinkAttribution()
        XCTAssertNil(sdk.deferredDeeplinkRequestID)
        XCTAssertNil(sdk.pendingDeferredDeeplinkAttribution)

        let newRequest = UUID()
        sdk.deferredDeeplinkRequestID = newRequest
        sdk.finishDeferredDeeplinkRequest(oldRequest, attribution: ["match_type": "deterministic"])

        XCTAssertEqual(calls, 0)
        XCTAssertEqual(sdk.deferredDeeplinkRequestID, newRequest)
        XCTAssertNil(sdk.pendingDeferredDeeplinkAttribution)
    }
}
