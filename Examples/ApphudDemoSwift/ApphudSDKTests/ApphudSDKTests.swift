//
//  ApphudSDKTests.swift
//  ApphudSDKTests
//
//  Created by Renat Kurbanov on 02.10.2023.
//  Copyright © 2023 Apphud. All rights reserved.
//

import XCTest
@testable import ApphudSDK
import StoreKitTest

final class ApphudSDKTests: XCTestCase {

    func test1Register() throws {
        // This is an example of a functional test case.
        // Use XCTAssert and related functions to verify your tests produce the correct results.
        // Any test you write for XCTest can be annotated as throws and async.
        // Mark your test throws to produce an unexpected failure when your test encounters an uncaught error.
        // Mark your test async to allow awaiting for asynchronous code to complete. Check the results with assertions afterwards.
        let key = "app_4sY9cLggXpMDDQMmvc5wXUPGReMp8G"
        let userId = "test_user_id"

        let expectation = XCTestExpectation(description: "Register user")

        Apphud.startManually(apiKey: key, userID: userId, deviceID: userId) {
            XCTAssertEqual(Apphud.userID(), userId)
            XCTAssertNotNil(Apphud.subscriptions())
            expectation.fulfill()
        }

        wait(for: [expectation], timeout: 10.0)
    }

    func test2Paywalls() async throws {

        let id = Apphud.userID()

        let paywalls = await Apphud.paywalls()
        let main = paywalls.first(where: { $0.name == ApphudPaywallID.main.rawValue })
        let mainOtherWay = await Apphud.paywall(ApphudPaywallID.main.rawValue)
        let weekly = main?.products.first(where: { $0.productId == "com.apphud.weekly" })

        XCTAssertNotNil(main)
        XCTAssertNotNil(mainOtherWay)
        XCTAssertTrue(ApphudInternal.shared.respondedStoreKitProducts)
    }

    func test3Purchase() async throws {
        let session = try SKTestSession(configurationFileNamed: "StoreKit")
        session.disableDialogs = true
        session.clearTransactions()

        if #available(iOS 17.0, *) {
            XCTAssertNoThrow(try session.buyProduct(productIdentifier: "com.apphud.weekly"))
        }
    }
}
