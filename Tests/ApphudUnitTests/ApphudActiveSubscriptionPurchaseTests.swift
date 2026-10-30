import XCTest
@testable import ApphudSDK

/// StoreKit 2 answers a purchase of the subscription already active on the device by itself:
/// it returns the existing transaction and never contacts the App Store (PLT-1415). A purchase
/// counts only when it changed something — a new transaction, or the App Store re-enabling
/// auto-renew and scheduling the requested offer.
final class ApphudActiveSubscriptionPurchaseTests: XCTestCase {

    private let offer = "trial_extended_7d"

    private func state(_ transactionID: UInt64 = 100, autoRenew: Bool, offer: String? = nil) -> ApphudActiveSubscriptionState {
        ApphudActiveSubscriptionState(transactionID: transactionID, renewsIntoProduct: autoRenew, renewalOfferID: offer)
    }

    private func didApply(before: ApphudActiveSubscriptionState?, after: ApphudActiveSubscriptionState?,
                          returned: UInt64?, offer: String? = nil) -> Bool {
        ApphudActiveSubscriptionPurchase.didApply(before: before, after: after, returnedTransactionID: returned, promotionalOfferID: offer)
    }

    // MARK: No active subscription: unchanged behaviour

    func testFirstPurchaseIsApplied() {
        XCTAssertTrue(didApply(before: nil, after: nil, returned: 200))
        XCTAssertTrue(didApply(before: nil, after: nil, returned: 200, offer: offer))
    }

    func testThrownPurchaseWithoutActiveSubscriptionStaysFailed() {
        XCTAssertFalse(didApply(before: nil, after: nil, returned: nil))
    }

    func testNewTransactionIsApplied() {
        XCTAssertTrue(didApply(before: state(autoRenew: false), after: state(200, autoRenew: true), returned: 200, offer: offer))
    }

    // MARK: StoreKit returned the active subscription unchanged

    /// The PLT-1415 case: cancelled trial, promo on the same product, StoreKit hands back the trial.
    func testPromoOnCancelledSubscriptionIsNotApplied() {
        let cancelled = state(autoRenew: false)
        XCTAssertFalse(didApply(before: cancelled, after: cancelled, returned: 100, offer: offer))
    }

    func testPromoOnRenewingSubscriptionWithoutTheOfferIsNotApplied() {
        let renewing = state(autoRenew: true)
        XCTAssertFalse(didApply(before: renewing, after: renewing, returned: 100, offer: offer))
    }

    func testPromoAlreadyScheduledIsApplied() {
        let scheduled = state(autoRenew: true, offer: offer)
        XCTAssertTrue(didApply(before: scheduled, after: scheduled, returned: 100, offer: offer))
    }

    func testRebuyOfCancelledSubscriptionIsNotApplied() {
        let cancelled = state(autoRenew: false)
        XCTAssertFalse(didApply(before: cancelled, after: cancelled, returned: 100))
    }

    func testRebuyOfRenewingSubscriptionStaysSuccessful() {
        let renewing = state(autoRenew: true)
        XCTAssertTrue(didApply(before: renewing, after: renewing, returned: 100))
    }

    /// Auto-renew is on but points at another product in the group (e.g. a scheduled downgrade).
    func testRebuyWhileRenewingIntoAnotherProductIsNotApplied() {
        let renewsElsewhere = state(autoRenew: false)
        XCTAssertFalse(didApply(before: renewsElsewhere, after: renewsElsewhere, returned: 100))
    }

    func testUnreadableStateAfterPurchaseIsNotApplied() {
        XCTAssertFalse(didApply(before: state(autoRenew: false), after: nil, returned: 100, offer: offer))
    }

    // MARK: Purchase threw, the App Store may still have applied it

    func testThrownPromoWhoseOfferWasScheduledIsApplied() {
        XCTAssertTrue(didApply(before: state(autoRenew: false), after: state(autoRenew: true, offer: offer), returned: nil, offer: offer))
    }

    func testThrownPromoWithoutTheOfferIsNotApplied() {
        XCTAssertFalse(didApply(before: state(autoRenew: false), after: state(autoRenew: true), returned: nil, offer: offer))
    }

    func testThrownRebuyThatReenabledAutoRenewIsApplied() {
        XCTAssertTrue(didApply(before: state(autoRenew: false), after: state(autoRenew: true), returned: nil))
    }

    func testThrownRebuyOfRenewingSubscriptionStaysFailed() {
        XCTAssertFalse(didApply(before: state(autoRenew: true), after: state(autoRenew: true), returned: nil))
    }

    func testThrownPurchaseThatChangedNothingStaysFailed() {
        let cancelled = state(autoRenew: false)
        XCTAssertFalse(didApply(before: cancelled, after: cancelled, returned: nil, offer: offer))
        XCTAssertFalse(didApply(before: cancelled, after: cancelled, returned: nil))
    }

    // MARK: The App Store processed the purchase after it returned

    /// Seen on a device: after the payment sheet, `purchase()` returned the trial, and seconds later
    /// a new transaction for the promotional offer appeared with auto-renew on but no renewal offer.
    func testNewTransactionAfterPurchaseIsApplied() {
        XCTAssertTrue(didApply(before: state(autoRenew: false), after: state(200, autoRenew: true), returned: 100, offer: offer))
        XCTAssertTrue(didApply(before: state(autoRenew: false), after: state(200, autoRenew: true), returned: nil, offer: offer))
    }

    func testInstantReturnIsNotWaitedFor() {
        XCTAssertEqual(ApphudActiveSubscriptionPurchase.renewalWait(purchaseDuration: 0.02), 0)
    }

    func testPurchaseAfterThePaymentSheetIsWaitedFor() {
        XCTAssertEqual(ApphudActiveSubscriptionPurchase.renewalWait(purchaseDuration: 1), 10)
        XCTAssertEqual(ApphudActiveSubscriptionPurchase.renewalWait(purchaseDuration: 87), 10)
    }
}
