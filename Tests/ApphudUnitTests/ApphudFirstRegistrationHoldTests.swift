//
//  ApphudFirstRegistrationHoldTests.swift
//  ApphudUnitTests
//
//  The first launch after an update: requests other than registrations and purchases wait for the
//  first registration.
//
import XCTest
@testable import ApphudSDK

final class ApphudFirstRegistrationHoldTests: XCTestCase {

    func testOpenRequestsGoAtOnce() {
        XCTAssertFalse(ApphudFirstRegistrationHold().holdIfClosed {})
    }

    func testClosedRequestsWaitUntilTheFirstRegistrationFinishes() {
        let hold = ApphudFirstRegistrationHold()
        hold.close()
        let ran = expectation(description: "runs once opened")
        var opened = false
        XCTAssertTrue(hold.holdIfClosed { XCTAssertTrue(opened); ran.fulfill() })

        opened = true
        hold.open()

        wait(for: [ran], timeout: 1)
        XCTAssertFalse(hold.isClosed)
    }

    func testRequestsGoAfterTheLimitWhenNothingOpensTheHold() {
        let hold = ApphudFirstRegistrationHold()
        hold.close(limit: 0.2)
        let ran = expectation(description: "runs after the limit")
        XCTAssertTrue(hold.holdIfClosed { ran.fulfill() })

        wait(for: [ran], timeout: 2)
    }

    func testAnEarlierLimitDoesNotOpenALaterHold() {
        let hold = ApphudFirstRegistrationHold()
        hold.close(limit: 0.2)
        hold.open()
        hold.close(limit: 10)

        let later = expectation(description: "the earlier limit has passed")
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) { later.fulfill() }
        wait(for: [later], timeout: 2)

        XCTAssertTrue(hold.isClosed)
        hold.open()
    }
}
