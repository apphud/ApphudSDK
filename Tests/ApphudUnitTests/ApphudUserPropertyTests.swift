//
//  ApphudUserPropertyTests.swift
//  ApphudUnitTests
//
//  Pure-logic unit tests for the user property payload.
//

import XCTest
@testable import ApphudSDK

final class ApphudUserPropertyTests: XCTestCase {

    func testPayloadWithoutAttributesIsUnchanged() throws {
        let json = try XCTUnwrap(property(value: "a").toJSON())

        XCTAssertEqual(Set(json.keys), ["name", "value", "set_once", "kind"])
    }

    func testAttributesAreSentAlongsideTheProperty() throws {
        let json = try XCTUnwrap(property(value: "a", attributes: ["extra": "x"]).toJSON())

        XCTAssertEqual(json["extra"] as? String, "x")
    }

    func testAttributesAreSentWhenThePropertyIsRemoved() throws {
        let json = try XCTUnwrap(property(value: nil, attributes: ["extra": "x"]).toJSON())

        XCTAssertEqual(json["extra"] as? String, "x")
    }

    func testAttributesNeverReplaceTheSDKFields() throws {
        let attributes = ["name": "other", "value": "other", "set_once": "other", "kind": "other"]
        let json = try XCTUnwrap(property(value: "a", attributes: attributes).toJSON())

        XCTAssertEqual(json["name"] as? String, "key")
        XCTAssertEqual(json["value"] as? String, "a")
        XCTAssertEqual(json["set_once"] as? Bool, false)
        XCTAssertEqual(json["kind"] as? String, "string")
    }

    func testIncrementWithoutValueStillSendsNothing() {
        let property = ApphudUserProperty(key: "key", value: nil, increment: true, setOnce: false,
                                          type: "integer", attributes: ["extra": "x"])

        XCTAssertNil(property.toJSON())
    }

    func testPlatformIsTheSDKsImplementation() {
        XCTAssertTrue(Apphud.platform is ApphudPlatform)
    }

    func testPlatformPassesTheKeysAttributesToThePendingProperty() async throws {
        Apphud.platform.setUserProperty(key: AttributedKey(), value: "a", setOnce: false)

        let pending = await pendingProperty(named: AttributedKey().name)
        let json = try XCTUnwrap(pending?.toJSON())

        XCTAssertEqual(json["extra"] as? String, "x")
        await ApphudDataActor.shared.setPendingUserProperties([])
    }

    /// `setUserProperty` hands the property to the data actor from a task of its own, so wait for it to land.
    private func pendingProperty(named name: String) async -> ApphudUserProperty? {
        for _ in 0..<100 {
            if let property = await ApphudDataActor.shared.pendingUserProps.first(where: { $0.key == name }) {
                return property
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
        }
        return nil
    }

    private func property(value: Any?, attributes: [String: String] = [:]) -> ApphudUserProperty {
        ApphudUserProperty(key: "key", value: value, increment: false, setOnce: false,
                           type: value == nil ? "null" : "string", attributes: attributes)
    }
}

private struct AttributedKey: PlatformUserPropertyKeyDescribing {
    let name = "platform_key"
    var attributes: [String: String] { ["extra": "x"] }
}
