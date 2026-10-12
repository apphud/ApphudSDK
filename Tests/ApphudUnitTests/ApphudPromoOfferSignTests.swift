import XCTest
@testable import ApphudSDK

/// StoreKit 2 sends a UUID application username to Apple as `appAccountToken`, and Apple checks
/// a promotional offer signature against the token's lowercase string, or against an empty string
/// when the purchase sends no token. `/sign_offer` is asked to sign exactly that value.
final class ApphudPromoOfferSignTests: XCTestCase {

    private let upperUUID = "2F8AE6A1-B7C5-4966-8DF8-89F750012506"

    private func signedUsername(for token: UUID?) -> String? {
        let params = ApphudInternal.promoOfferSignParams(productID: "p", discountID: "o",
                                                         appAccountToken: token,
                                                         deviceID: "D", userID: "U")
        return params["application_username"] as? String
    }

    func testTokenIsSignedLowercase() {
        XCTAssertEqual(signedUsername(for: UUID(uuidString: upperUUID)), "2f8ae6a1-b7c5-4966-8df8-89f750012506")
    }

    func testNoTokenIsSignedAsEmptyString() {
        XCTAssertEqual(signedUsername(for: nil), "")
    }

    func testOnlyAUUIDUsernameIsAToken() {
        XCTAssertNotNil(ApphudStoreKitWrapper.appAccountToken(from: upperUUID))
        XCTAssertNil(ApphudStoreKitWrapper.appAccountToken(from: "Custom-Device-42"))
        XCTAssertNil(ApphudStoreKitWrapper.appAccountToken(from: nil))
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
