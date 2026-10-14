import XCTest
@testable import ApphudSDK

/// The automatic paths skip a transaction whose `appAccountToken` belongs to another account, and
/// purchases made through the SDK carry the account's token. The token is a UUID user id, or the
/// installation id for everyone else, so another account is known only by a user id this install
/// bought with.
final class ApphudAnotherAccountTests: XCTestCase {

    private let installationID = "6F9619FF-8B86-D011-B42D-00C04FC964FF"
    private let alice = UUID(uuidString: "2F8AE6A1-B7C5-4966-8DF8-89F750012506")!
    private let bob = UUID(uuidString: "7F0CDC21-D671-48C5-B8AE-BD1CADAE2083")!
    private var defaults: UserDefaults!
    private var suiteName = ""

    override func setUp() {
        super.setUp()
        suiteName = "ApphudAnotherAccountTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
    }

    override func tearDown() {
        UserDefaults().removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func identity(user: String?) -> ApphudIdentity {
        ApphudIdentity(installationID: installationID, anonymousID: "anon-1", userID: user)
    }

    private func belongsToAnotherAccount(_ token: UUID?, current user: String?) -> Bool {
        ApphudStoreKitWrapper.belongsToAnotherAccount(token, identity: identity(user: user),
                                                      purchaseUserTokens: ApphudStoreKitWrapper.purchaseUserTokens(defaults: defaults))
    }

    func testAPurchaseRemembersItsTokenOnlyWhenItIsTheUsersID() {
        ApphudStoreKitWrapper.rememberPurchaseToken(alice, identity: identity(user: alice.uuidString.lowercased()), defaults: defaults)
        ApphudStoreKitWrapper.rememberPurchaseToken(UUID(uuidString: installationID)!, identity: identity(user: nil), defaults: defaults)
        ApphudStoreKitWrapper.rememberPurchaseToken(UUID(uuidString: installationID)!, identity: identity(user: "carol@example.com"), defaults: defaults)
        ApphudStoreKitWrapper.rememberPurchaseToken(alice, identity: identity(user: alice.uuidString), defaults: defaults)

        XCTAssertEqual(ApphudStoreKitWrapper.purchaseUserTokens(defaults: defaults), [alice],
                       "the installation id names no account; a user id is kept once")
    }

    func testAnotherUserWhoBoughtHereOwnsTheTransaction() {
        ApphudStoreKitWrapper.rememberPurchaseToken(alice, identity: identity(user: alice.uuidString), defaults: defaults)

        XCTAssertTrue(belongsToAnotherAccount(alice, current: bob.uuidString), "bob signed in after alice")
        XCTAssertTrue(belongsToAnotherAccount(alice, current: "carol@example.com"))
        XCTAssertTrue(belongsToAnotherAccount(alice, current: nil), "alice logged out")
        XCTAssertFalse(belongsToAnotherAccount(alice, current: alice.uuidString.lowercased()), "alice again")
    }

    func testATokenTheSDKDidNotPutIntoAPurchaseNamesNoAccount() {
        ApphudStoreKitWrapper.rememberPurchaseToken(alice, identity: identity(user: alice.uuidString), defaults: defaults)

        XCTAssertFalse(belongsToAnotherAccount(nil, current: bob.uuidString), "older purchases carry no token")
        XCTAssertFalse(belongsToAnotherAccount(UUID(), current: bob.uuidString), "the app's own token, or another device's")
        XCTAssertFalse(belongsToAnotherAccount(UUID(uuidString: installationID), current: bob.uuidString),
                       "this installation's token is anybody's who used it")
    }

    func testTheTokenDoesNotWaitForTheStoreKit1Swizzle() {
        let sdk = ApphudInternal.shared
        let saved = sdk.identity
        defer { sdk.identity = saved }

        sdk.identity = identity(user: nil)
        XCTAssertEqual(ApphudStoreKitWrapper.shared.appAccountToken(), UUID(uuidString: installationID))
        sdk.identity = identity(user: alice.uuidString)
        XCTAssertEqual(ApphudStoreKitWrapper.shared.appAccountToken(), alice)
    }
}
