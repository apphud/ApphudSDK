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
}
