import XCTest
@testable import ApphudSDK

/// PLT-1151: StoreKit 2 sends the application username to Apple as `appAccountToken` only
/// when it is a UUID, and Apple checks the signature against the token's lowercase string.
/// The value `/sign_offer` signs must be that lowercase token, or an empty string when the
/// purchase sends no token.
final class ApphudPromoOfferSignTests: XCTestCase {

    private let upperUUID = "2F8AE6A1-B7C5-4966-8DF8-89F750012506"

    private func signedUsername(for username: String?) -> String? {
        let params = ApphudInternal.promoOfferSignParams(productID: "p", discountID: "o",
                                                         appAccountToken: ApphudStoreKitWrapper.appAccountToken(from: username),
                                                         deviceID: "D", userID: "U")
        return params["application_username"] as? String
    }

    func testUppercaseUUIDIsSignedLowercase() {
        XCTAssertEqual(signedUsername(for: upperUUID), "2f8ae6a1-b7c5-4966-8df8-89f750012506")
    }

    func testNonUUIDUsernameSignsEmptyString() {
        // A custom non-UUID user/device id is never sent as appAccountToken.
        XCTAssertNil(ApphudStoreKitWrapper.appAccountToken(from: "custom-device-42"))
        XCTAssertEqual(signedUsername(for: "custom-device-42"), "")
    }

    func testMissingUsernameIsEmptyString() {
        XCTAssertNil(ApphudStoreKitWrapper.appAccountToken(from: nil))
        XCTAssertEqual(signedUsername(for: nil), "")
    }

    func testTokenIsTheUsernameUUID() {
        XCTAssertEqual(ApphudStoreKitWrapper.appAccountToken(from: upperUUID), UUID(uuidString: "2f8ae6a1-b7c5-4966-8df8-89f750012506"))
    }

    func testOtherFieldsAreSentUnchanged() {
        let params = ApphudInternal.promoOfferSignParams(productID: "com.app.Year", discountID: "Offer_7D",
                                                         appAccountToken: UUID(uuidString: upperUUID),
                                                         deviceID: "DEV-ID", userID: "User-ID")
        XCTAssertEqual(params["product_id"] as? String, "com.app.Year")
        XCTAssertEqual(params["offer_id"] as? String, "Offer_7D")
        XCTAssertEqual(params["device_id"] as? String, "DEV-ID")
        XCTAssertEqual(params["user_id"] as? String, "User-ID")
        XCTAssertEqual(params.count, 5)
    }
}
