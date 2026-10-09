import XCTest
@testable import ApphudSDK

/// StoreKit 2 sends a UUID application username to Apple as `appAccountToken`,
/// and Apple checks the signature against the token's lowercase string, so `/sign_offer`
/// signs a UUID username in lowercase. Any other username is sent unchanged.
final class ApphudPromoOfferSignTests: XCTestCase {

    private let upperUUID = "2F8AE6A1-B7C5-4966-8DF8-89F750012506"

    private func signedUsername(for username: String?) -> String? {
        let params = ApphudInternal.promoOfferSignParams(productID: "p", discountID: "o",
                                                         applicationUsername: username,
                                                         deviceID: "D", userID: "U")
        return params["application_username"] as? String
    }

    func testUppercaseUUIDIsSignedLowercase() {
        XCTAssertEqual(signedUsername(for: upperUUID), "2f8ae6a1-b7c5-4966-8df8-89f750012506")
    }

    func testNonUUIDUsernameIsSentUnchanged() {
        XCTAssertNil(ApphudStoreKitWrapper.appAccountToken(from: "Custom-Device-42"))
        XCTAssertEqual(signedUsername(for: "Custom-Device-42"), "Custom-Device-42")
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
                                                         applicationUsername: upperUUID,
                                                         deviceID: "DEV-ID", userID: "User-ID")
        XCTAssertEqual(params["product_id"] as? String, "com.app.Year")
        XCTAssertEqual(params["offer_id"] as? String, "Offer_7D")
        XCTAssertEqual(params["device_id"] as? String, "DEV-ID")
        XCTAssertEqual(params["user_id"] as? String, "User-ID")
        XCTAssertEqual(params.count, 5)
    }
}
