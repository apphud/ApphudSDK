import XCTest
@testable import ApphudSDK

/// Which StoreKit transactions the cached user already covers, so they need no upload. Apple keeps a
/// subscription's original transaction id when it is bought again (APPHUD-884).
final class ApphudTrackedTransactionTests: XCTestCase {

    private let product = "com.apphud.weekly"
    private let originalID: UInt64 = 100
    private let week: TimeInterval = 7 * 86_400
    private let started = Date(timeIntervalSince1970: 1_750_000_000)
    private lazy var expires = started.addingTimeInterval(week)

    private func subscription(status: String = "regular", expires: Date? = nil, canceled: Date? = nil,
                              originalID: String? = "100", group: String = "group_1") throws -> ApphudSubscription {
        var json: [String: Any] = [
            "id": "sub_1", "product_id": product, "started_at": started.apphudIsoString,
            "expires_at": (expires ?? self.expires).apphudIsoString, "in_retry_billing": false,
            "autorenew_enabled": true, "introductory_activated": false, "environment": "sandbox",
            "local": false, "group_id": group, "status": status
        ]
        json["original_transaction_id"] = originalID
        json["cancelled_at"] = canceled?.apphudIsoString
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ApphudSubscription.self, from: JSONSerialization.data(withJSONObject: json))
    }

    private func purchase(transactionID: String) throws -> ApphudNonRenewingPurchase {
        let json: [String: Any] = ["kind": "nonrenewable", "product_id": product, "started_at": started.apphudIsoString, "local": false,
                                   "environment": "sandbox", "transaction_id": transactionID]
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        return try decoder.decode(ApphudNonRenewingPurchase.self, from: JSONSerialization.data(withJSONObject: json))
    }

    /// A weekly transaction of the same original id, bought `offset` after the cached period ended.
    private func isTracked(boughtAfterExpiry offset: TimeInterval, by subscription: ApphudSubscription,
                           product: String? = nil) -> Bool {
        isTracked(purchased: expires.addingTimeInterval(offset), by: [subscription], product: product)
    }

    private func isTracked(purchased: Date, by subscriptions: [ApphudSubscription] = [],
                           purchases: [ApphudNonRenewingPurchase] = [], product: String? = nil,
                           expires expiration: Date?? = nil) -> Bool {
        ApphudInternal.isAlreadyTracked(originalTransactionID: originalID, productID: product ?? self.product,
                                        purchaseDate: purchased,
                                        expirationDate: expiration ?? purchased.addingTimeInterval(week),
                                        purchases: purchases, subscriptions: subscriptions)
    }

    // MARK: Bought again

    func testResubscribeAfterExpiryIsNotTracked() throws {
        XCTAssertFalse(isTracked(boughtAfterExpiry: 86_400, by: try subscription(status: "expired")))
    }

    func testResubscribeRightAfterExpiryIsNotTracked() throws {
        XCTAssertFalse(isTracked(boughtAfterExpiry: 1, by: try subscription(status: "expired")))
    }

    func testResubscribeWhileTheCacheStillSaysActiveIsNotTracked() throws {
        XCTAssertFalse(isTracked(boughtAfterExpiry: 86_400, by: try subscription(status: "regular")))
    }

    func testPurchaseAfterARefundIsNotTracked() throws {
        let canceled = started.addingTimeInterval(3_600)
        let refunded = try subscription(status: "refunded", canceled: canceled)
        XCTAssertFalse(isTracked(purchased: canceled.addingTimeInterval(60), by: [refunded]))
    }

    // MARK: Known to the backend

    func testFirstTransactionIsTracked() throws {
        XCTAssertTrue(isTracked(purchased: started, by: [try subscription()]))
    }

    func testTransactionOfTheCachedPeriodIsTracked() throws {
        let renewed = try subscription(expires: expires.addingTimeInterval(week))
        XCTAssertTrue(isTracked(purchased: expires, by: [renewed]))
    }

    func testPastTransactionOfAnExpiredSubscriptionIsTracked() throws {
        XCTAssertTrue(isTracked(purchased: expires.addingTimeInterval(-week), by: [try subscription(status: "expired")]))
    }

    func testOnTimeRenewalOfAnActiveSubscriptionIsTracked() throws {
        XCTAssertTrue(isTracked(boughtAfterExpiry: 0, by: try subscription()))
    }

    func testRecoveryWithinTheGracePeriodIsTracked() throws {
        let grace = try subscription(status: "grace", expires: expires.addingTimeInterval(3 * 86_400))
        XCTAssertTrue(isTracked(boughtAfterExpiry: 86_400, by: grace))
    }

    func testRefundedTransactionItselfIsTracked() throws {
        let refunded = try subscription(status: "refunded", canceled: started.addingTimeInterval(3_600))
        XCTAssertTrue(isTracked(purchased: started, by: [refunded]))
    }

    func testTransactionWithoutAnExpirationIsTracked() throws {
        let purchased = expires.addingTimeInterval(86_400)
        XCTAssertTrue(isTracked(purchased: purchased, by: [try subscription(status: "expired")], expires: .some(nil)))
    }

    func testNonRenewingPurchaseIsTrackedByItsTransactionID() throws {
        XCTAssertTrue(isTracked(purchased: expires, purchases: [try purchase(transactionID: "100")]))
    }

    // MARK: Unrelated

    func testOtherProductIsNotTracked() throws {
        XCTAssertFalse(isTracked(boughtAfterExpiry: -week, by: try subscription(), product: "com.apphud.monthly"))
    }

    func testSubscriptionWithoutAnOriginalIDDoesNotTrackALaterTransaction() throws {
        XCTAssertFalse(isTracked(boughtAfterExpiry: -86_400, by: try subscription(originalID: nil)))
    }
}
