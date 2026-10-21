import XCTest
@testable import ApphudSDK

final class ApphudObservedTransactionsTests: XCTestCase {
    private let identity = ApphudIdentity(installationID: "install", anonymousID: "anon", userID: "Alice")

    func testSuccessfulObservationIsDeliveredOnce() throws {
        var state = ApphudObservedTransactions()
        let ticket = try XCTUnwrap(state.beginObservation(1, identity: identity))
        XCTAssertNil(state.beginObservation(1, identity: identity), "duplicate while pending")
        state.acknowledge(1, identity: identity)
        XCTAssertTrue(state.completeObservation(1, ticket: ticket, success: true))
        XCTAssertNil(state.beginObservation(1, identity: identity), "duplicate after success")
    }

    func testFailureAllowsAnActualRetryButNotDuplicateCompletion() throws {
        var state = ApphudObservedTransactions()
        let first = try XCTUnwrap(state.beginObservation(1, identity: identity))
        XCTAssertTrue(state.completeObservation(1, ticket: first, success: false))
        XCTAssertFalse(state.completeObservation(1, ticket: first, success: false))
        let retry = try XCTUnwrap(state.beginObservation(1, identity: identity))
        state.acknowledge(1, identity: identity)
        XCTAssertTrue(state.completeObservation(1, ticket: retry, success: true))
        XCTAssertNil(state.beginObservation(1, identity: identity))
    }

    func testSDKPurchaseNeverBecomesObserved() {
        var state = ApphudObservedTransactions()
        state.recordSDKPurchase(1)
        state.acknowledge(1, identity: identity)
        state.processingEnded(1, generation: state.generation)
        XCTAssertTrue(state.isSDKPurchase(1))
        XCTAssertNil(state.beginObservation(1, identity: identity))
    }

    func testSDKPurchaseWinningAfterLegacyArrivalSuppressesNotification() throws {
        var state = ApphudObservedTransactions()
        let ticket = try XCTUnwrap(state.beginObservation(1, identity: identity))
        state.recordSDKPurchase(1)
        state.acknowledge(1, identity: identity)
        XCTAssertFalse(state.completeObservation(1, ticket: ticket, success: true))
    }

    func testAcknowledgementIsBoundToIdentity() {
        var state = ApphudObservedTransactions()
        state.acknowledge(1, identity: identity)
        let other = ApphudIdentity(installationID: "install", anonymousID: "anon", userID: "Bob")
        XCTAssertTrue(state.hasAcknowledgement(1, identity: identity))
        XCTAssertFalse(state.hasAcknowledgement(1, identity: other))
        XCTAssertNil(state.beginObservation(1, identity: other))
        XCTAssertFalse(state.hasAcknowledgement(2, identity: identity))
    }

    func testAcknowledgementFromAnotherIdentityCannotCompleteObservation() throws {
        var state = ApphudObservedTransactions()
        let other = ApphudIdentity(installationID: "install", anonymousID: "anon", userID: "Bob")
        let ticket = try XCTUnwrap(state.beginObservation(1, identity: other))
        state.acknowledge(1, identity: identity)
        XCTAssertFalse(state.completeObservation(1, ticket: ticket, success: true))
    }

    func testLogoutInvalidatesQueuedNotificationEvenWithSameIDs() throws {
        var state = ApphudObservedTransactions()
        let ticket = try XCTUnwrap(state.beginObservation(1, identity: identity))
        state.acknowledge(1, identity: identity)
        state.reset()
        XCTAssertFalse(state.completeObservation(1, ticket: ticket, success: true))
        XCTAssertFalse(state.hasAcknowledgement(1, identity: identity))
        XCTAssertNotNil(state.beginObservation(1, identity: identity))
    }

    func testEachNativeTransactionIsFinishedAtMostOnce() {
        var state = ApphudObservedTransactions()
        let generation = state.generation
        XCTAssertTrue(state.claimFinish(1, generation: generation))
        XCTAssertFalse(state.claimFinish(1, generation: generation))
        XCTAssertTrue(state.claimFinish(2, generation: generation))
    }

    func testOldFinisherCannotClaimANewSession() {
        var state = ApphudObservedTransactions()
        let old = state.generation
        state.reset()
        XCTAssertFalse(state.claimFinish(1, generation: old))
        XCTAssertTrue(state.claimFinish(1, generation: state.generation))
    }

    func testCompletedHistoryIsBounded() {
        var state = ApphudObservedTransactions(limit: 2)
        for id: UInt64 in [1, 2, 3] { state.acknowledge(id, identity: identity) }
        XCTAssertFalse(state.hasAcknowledgement(1, identity: identity))
        XCTAssertTrue(state.hasAcknowledgement(3, identity: identity))
    }

    func testActiveDeliverySurvivesHistoryTrimming() throws {
        var state = ApphudObservedTransactions(limit: 1)
        let ticket = try XCTUnwrap(state.beginObservation(1, identity: identity))
        state.acknowledge(2, identity: identity)
        state.acknowledge(3, identity: identity)
        state.acknowledge(1, identity: identity)
        XCTAssertTrue(state.completeObservation(1, ticket: ticket, success: true))
    }

    func testPendingSDKPurchaseSurvivesHistoryTrimming() {
        var state = ApphudObservedTransactions(limit: 1)
        state.recordSDKPurchase(1)
        state.acknowledge(2, identity: identity)
        state.acknowledge(3, identity: identity)
        XCTAssertTrue(state.isSDKPurchase(1))
        state.processingEnded(1, generation: state.generation)
        state.acknowledge(4, identity: identity)
        XCTAssertFalse(state.isSDKPurchase(1))
    }
}
