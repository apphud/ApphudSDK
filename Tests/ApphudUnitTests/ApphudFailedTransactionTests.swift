//
//  ApphudFailedTransactionTests.swift
//  ApphudUnitTests
//
//  Finishing of failed legacy payment-queue transactions.
//

import XCTest
import StoreKit
@testable import ApphudSDK

final class ApphudFailedTransactionTests: XCTestCase {

    /// A `.failed` transaction as StoreKit redelivers it to the payment queue observer.
    /// It is handed to the real `SKPaymentQueue.finishTransaction`, which tolerates a
    /// transaction it does not know only while `transactionIdentifier` is nil.
    private final class FailedTransaction: SKPaymentTransaction {
        private let productId: String
        private let failure: Error?

        init(productId: String, error: Error?) {
            self.productId = productId
            self.failure = error
            super.init()
        }

        override var transactionState: SKPaymentTransactionState { .failed }
        override var payment: SKPayment {
            let payment = SKMutablePayment()
            payment.productIdentifier = productId
            return payment
        }
        override var error: Error? { failure }
        override var transactionIdentifier: String? { nil }
        override var original: SKPaymentTransaction? { nil }
    }

    private var originalObserverMode = false

    override func setUp() {
        super.setUp()
        originalObserverMode = ApphudUtils.shared.storeKitObserverMode
    }

    override func tearDown() {
        ApphudUtils.shared.storeKitObserverMode = originalObserverMode
        super.tearDown()
    }

    // Nobody else finishes a failed transaction once the SK1 purchase path is gone; left
    // unfinished, StoreKit redelivers it on every launch.
    func testFailedTransactionIsFinishedOutsideObserverMode() {
        ApphudUtils.shared.storeKitObserverMode = false
        let transaction = FailedTransaction(productId: "com.apphud.unit.weekly", error: SKError(.paymentCancelled))
        let finished = expectation(forNotification: _ApphudWillFinishTransactionNotification, object: transaction)

        ApphudStoreKitWrapper.shared.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [transaction])

        wait(for: [finished], timeout: 3)
    }

    // In observer mode the host app owns finishing, exactly like every other state.
    func testFailedTransactionIsNotFinishedInObserverMode() {
        ApphudUtils.shared.storeKitObserverMode = true
        let transaction = FailedTransaction(productId: "com.apphud.unit.weekly", error: SKError(.paymentCancelled))
        let finished = expectation(forNotification: _ApphudWillFinishTransactionNotification, object: transaction)
        finished.isInverted = true

        ApphudStoreKitWrapper.shared.paymentQueue(SKPaymentQueue.default(), updatedTransactions: [transaction])

        wait(for: [finished], timeout: 1)
    }
}
