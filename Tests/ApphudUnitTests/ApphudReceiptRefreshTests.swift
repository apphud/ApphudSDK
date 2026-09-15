//
//  ApphudReceiptRefreshTests.swift
//  ApphudUnitTests
//
//  Receipt refreshing shared by concurrent callers (legacy SKReceiptRefreshRequest).
//

import XCTest
import StoreKit
@testable import ApphudSDK

final class ApphudReceiptRefreshTests: XCTestCase {

    /// Stands in for StoreKit: never starts a real refresh, so the tests drive the
    /// delegate themselves and nothing leaks into the shared wrapper afterwards.
    private final class StubRefreshRequest: SKReceiptRefreshRequest {
        override func start() {}
        override func cancel() {}
    }

    private var wrapper: ApphudStoreKitWrapper { ApphudStoreKitWrapper.shared }
    private var started: [StubRefreshRequest] = []
    private var originalTimeout: TimeInterval = 0

    override func setUp() {
        super.setUp()
        started = []
        originalTimeout = wrapper.receiptRefreshTimeout
        wrapper.makeReceiptRefreshRequest = { [weak self] in
            let request = StubRefreshRequest()
            self?.started.append(request)
            return request
        }
    }

    override func tearDown() {
        wrapper.makeReceiptRefreshRequest = { SKReceiptRefreshRequest() }
        wrapper.receiptRefreshTimeout = originalTimeout
        super.tearDown()
    }

    /// Lets the wrapper's main-queue bookkeeping run before the test drives the delegate.
    private func drainMainQueue() {
        let settled = expectation(description: "main queue drained")
        DispatchQueue.main.async { settled.fulfill() }
        wait(for: [settled], timeout: 1)
    }

    // Two submissions can hit a missing receipt at the same time (Transaction.updates
    // delivering two transactions, or a restore during a purchase). Each caller awaits
    // its own continuation, so every callback must fire — a dropped one hangs a purchase.
    func testOverlappingReceiptRefreshCallersShareOneRequestAndBothComplete() throws {
        let first = expectation(description: "first caller completes")
        let second = expectation(description: "second caller completes")

        wrapper.refreshReceipt { first.fulfill() }
        wrapper.refreshReceipt { second.fulfill() }
        drainMainQueue()

        XCTAssertEqual(started.count, 1, "Overlapping callers must share one StoreKit request")
        wrapper.requestDidFinish(try XCTUnwrap(started.first))

        wait(for: [first, second], timeout: 3)
    }

    func testReceiptRefreshFailureDrainsAllCallers() throws {
        let first = expectation(description: "first caller completes after a failed refresh")
        let second = expectation(description: "second caller completes after a failed refresh")

        wrapper.refreshReceipt { first.fulfill() }
        wrapper.refreshReceipt { second.fulfill() }
        drainMainQueue()

        wrapper.request(try XCTUnwrap(started.first), didFailWithError: SKError(.unknown))

        wait(for: [first, second], timeout: 3)
    }

    // A completion for some other request must not release callers waiting on the one in flight.
    func testCompletionOfAForeignRequestIsIgnored() throws {
        let caller = expectation(description: "caller completes only for its own request")

        wrapper.refreshReceipt { caller.fulfill() }
        drainMainQueue()

        wrapper.requestDidFinish(StubRefreshRequest())
        drainMainQueue()
        XCTAssertEqual(started.count, 1)

        wrapper.requestDidFinish(try XCTUnwrap(started.first))
        wait(for: [caller], timeout: 3)
    }

    // StoreKit never calling back must not wedge every later submission: the watchdog
    // releases the waiting callers, who proceed without a receipt.
    func testStuckRefreshReleasesCallersAfterTimeout() {
        wrapper.receiptRefreshTimeout = 0.2
        let first = expectation(description: "first caller released by the watchdog")
        let second = expectation(description: "second caller released by the watchdog")

        wrapper.refreshReceipt { first.fulfill() }
        wrapper.refreshReceipt { second.fulfill() }
        drainMainQueue()
        XCTAssertEqual(started.count, 1, "The second caller must wait on the same stuck request, not start its own")

        wait(for: [first, second], timeout: 3)
    }
}
