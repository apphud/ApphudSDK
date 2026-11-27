//
//  ApphudPlatformSPITests.swift
//  ApphudUnitTests
//
//  The platform facade is reachable from another module through `@_spi(Platform)`,
//  without `@testable`.
//

import XCTest
@_spi(Platform) import ApphudSDK

final class ApphudPlatformSPITests: XCTestCase {

    private struct Key: PlatformUserPropertyKeyDescribing {
        let name = "spi_key"
        let attributes = ["kind": "spi"]
    }

    func testFacadeIsReachableThroughSPI() {
        let platform: any PlatformProtocol = Apphud.platform
        let key: any PlatformUserPropertyKeyDescribing = Key()

        XCTAssertEqual(key.name, "spi_key")
        XCTAssertFalse(platform.sessionId.isEmpty)
    }
}
