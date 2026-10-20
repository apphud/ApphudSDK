//
//  ApphudIdentityVersion1Tests.swift
//  ApphudUnitTests
//
//  Identity version 1, the default: the ids and requests of SDK 4.6.1.
//
import XCTest
@testable import ApphudSDK

private final class RecordingProtocol: URLProtocol {

    private static let lock = NSLock()
    private static var _urls: [URL] = []

    static var urls: [URL] {
        lock.lock(); defer { lock.unlock() }
        return _urls
    }

    static func reset() {
        lock.lock(); defer { lock.unlock() }
        _urls = []
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        if let url = request.url { Self._urls.append(url) }
        Self.lock.unlock()
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{\"data\":{\"results\":{}}}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

/// Answers every request with a client error: no fallback mode, which loads products.
private final class FailingProtocol: URLProtocol {
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        let response = HTTPURLResponse(url: request.url!, statusCode: 400, httpVersion: nil, headerFields: nil)!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data())
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class ApphudIdentityVersion1Tests: XCTestCase {

    private let sdk = ApphudInternal.shared
    private var saved: (version: ApphudIdentityVersion, deviceID: String, userID: String, identity: ApphudIdentity,
                        isRedownload: Bool, reinstallTracked: Bool)!

    override func setUp() {
        super.setUp()
        saved = (sdk.identityVersion, sdk.currentDeviceID, sdk.v1UserID, sdk.identity, sdk.isRedownload, sdk.reinstallTracked)
        sdk.identityVersion = .v1
        sdk.currentDeviceID = "DEVICE-1"
        sdk.v1UserID = "USER-1"
        // Version 2 ids set as well: version 1 must not send them.
        sdk.identity = ApphudIdentity(installationID: "inst-1", anonymousID: "anon-1", userID: "user-2", isReinstall: true)
    }

    override func tearDown() {
        sdk.identityVersion = saved.version
        sdk.currentDeviceID = saved.deviceID
        sdk.v1UserID = saved.userID
        sdk.identity = saved.identity
        sdk.isRedownload = saved.isRedownload
        sdk.reinstallTracked = saved.reinstallTracked
        super.tearDown()
    }

    func testVersion1IsTheDefault() {
        XCTAssertEqual(ApphudInternal().identityVersion, .v1)
        XCTAssertEqual(ApphudIdentityVersion.v1.rawValue, 1)
        XCTAssertEqual(ApphudIdentityVersion.v2.rawValue, 2)
    }

    func testALogoutBeforeAStartFollowsTheVersionThatRanLast() {
        let suiteName = "ApphudIdentityVersion1Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defer { UserDefaults().removePersistentDomain(forName: suiteName) }
        let launch = ApphudInternal()
        launch.identityStore = ApphudIdentityStore(defaults: defaults)

        XCTAssertTrue(launch.logoutRunsVersion1, "nothing ran yet: the logout of SDK 4.6")
        defaults.set("v2", forKey: ApphudIdentityStore.identityVersionKey)
        XCTAssertFalse(launch.logoutRunsVersion1, "version 2 ran last: its logout")
        defaults.set("v1", forKey: ApphudIdentityStore.identityVersionKey)
        XCTAssertTrue(launch.logoutRunsVersion1)

        launch.chooseIdentityVersion(.v2)

        XCTAssertFalse(launch.logoutRunsVersion1, "after a start the version of this launch decides")
    }

    func testTheVersionIsReadOncePerLaunch() {
        let launch = ApphudInternal()

        launch.chooseIdentityVersion(.v2)
        launch.chooseIdentityVersion(.v1)

        XCTAssertEqual(launch.identityVersion, .v2, "a later start keeps the first choice")
    }

    /// A launch with a cached customer whose store says version 1 took the ids of version 2 over.
    @MainActor
    private func launchAfterVersion2(_ version: ApphudIdentityVersion, takeover: Bool) -> (ApphudInternal, () -> Void) {
        let suiteName = "ApphudIdentityVersion1Tests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        let launch = ApphudInternal()
        launch.identityStore = ApphudIdentityStore(defaults: defaults)
        if takeover { launch.identityStore.markVersion1(tookOverVersion2: true) }
        launch.chooseIdentityVersion(version)
        launch.currentUser = ApphudUser(userID: "anon-1")
        return (launch, { UserDefaults().removePersistentDomain(forName: suiteName) })
    }

    @MainActor
    private func isPerformed(_ launch: ApphudInternal) async -> Bool {
        var performed = false
        launch.performWhenUserRegistered { performed = true }
        for _ in 0..<50 { await Task.yield() }
        return performed
    }

    @MainActor
    func testAfterVersion2RequestsWaitForTheFirstRegistrationOfVersion1() async {
        let (launch, cleanUp) = launchAfterVersion2(.v1, takeover: true)
        defer { cleanUp() }
        var performed = false
        launch.performWhenUserRegistered { performed = true }
        for _ in 0..<50 { await Task.yield() }
        XCTAssertFalse(performed, "the backend may not know the device id yet: the cached customer is no registration")

        // A successful registration, as `registerUser` handles it.
        launch.identityStore.markVersion1Registered()
        launch.performAllUserRegisteredBlocks()
        for _ in 0..<50 { await Task.yield() }

        XCTAssertTrue(performed, "it goes once the registration of version 1 succeeded")
        let afterwards = await isPerformed(launch)
        XCTAssertTrue(afterwards)
    }

    @MainActor
    func testAFailedFirstRegistrationOfVersion1ReleasesWhatWaitedAsSDK46WithACachedCustomer() async {
        let (launch, cleanUp) = launchAfterVersion2(.v1, takeover: true)
        defer { cleanUp() }
        var performed = false
        launch.performWhenUserRegistered { performed = true }
        for _ in 0..<50 { await Task.yield() }
        XCTAssertFalse(performed)

        launch.endVersion1LaunchRegistration()
        for _ in 0..<50 { await Task.yield() }

        XCTAssertTrue(performed, "never waits longer than the first registration of the launch")
        XCTAssertTrue(launch.identityStore.isVersion1RegistrationPending, "the next launch registers again")
        let later = await isPerformed(launch)
        XCTAssertTrue(later)
    }

    /// The registration of version 1 against a stubbed backend, from `continueToRegisteringUser`.
    /// `released`: the request waiting for it goes within the timeout.
    @MainActor
    private func registerVersion1(_ launch: ApphudInternal, answering protocolClass: URLProtocol.Type,
                                  released: Bool = true) async {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [protocolClass]
        ApphudHttpClient.testURLSessionConfiguration = configuration
        defer { ApphudHttpClient.testURLSessionConfiguration = nil }
        launch.httpClient = ApphudHttpClient()
        launch.currentDeviceID = "DEVICE-NEW"
        launch.v1UserID = "anon-1"
        // Only the registration: the work of an app that became active and the payment queue swizzle
        // touch shared StoreKit state.
        launch.didHandleBecomeActive = true
        UserDefaults.standard.set(true, forKey: launch.swizzlePaymentDisabledKey)
        defer { UserDefaults.standard.removeObject(forKey: launch.swizzlePaymentDisabledKey) }
        let waited = expectation(description: "released")
        waited.isInverted = !released
        launch.performWhenUserRegistered { waited.fulfill() }

        launch.continueToRegisteringUser()

        await fulfillment(of: [waited], timeout: released ? 10 : 2)
        // No retry runs on after the test.
        launch.httpClient = nil
        NSObject.cancelPreviousPerformRequests(withTarget: launch)
    }

    @MainActor
    func testARegistrationOfVersion1AfterVersion2ClearsTheFlag() async {
        let (launch, cleanUp) = launchAfterVersion2(.v1, takeover: true)
        defer { cleanUp() }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecordingProtocol.self]
        ApphudHttpClient.testURLSessionConfiguration = configuration
        defer { ApphudHttpClient.testURLSessionConfiguration = nil }
        launch.httpClient = ApphudHttpClient()
        launch.currentDeviceID = "DEVICE-NEW"
        launch.v1UserID = "anon-1"
        let answered = expectation(description: "answered")

        // The request of the registration only: what follows it loads products and swizzles StoreKit.
        launch.updateUser(fields: ["user_id": "anon-1", "initial_call": true]) { _, _, _, _, _, _, _ in answered.fulfill() }
        await fulfillment(of: [answered], timeout: 10)

        XCTAssertFalse(launch.identityStore.isVersion1RegistrationPending, "the backend has seen the device id")
    }

    @MainActor
    func testAFailedRegistrationOfVersion1AfterVersion2ReleasesWhatWaited() async {
        let (launch, cleanUp) = launchAfterVersion2(.v1, takeover: true)
        defer { cleanUp() }

        await registerVersion1(launch, answering: FailingProtocol.self)

        XCTAssertTrue(launch.identityStore.isVersion1RegistrationPending)
    }

    @MainActor
    func testAFailedRegistrationOfVersion1AfterVersion2WithoutACachedCustomerKeepsWhatWaitedAsSDK46() async {
        let (launch, cleanUp) = launchAfterVersion2(.v1, takeover: true)
        defer { cleanUp() }
        launch.currentUser = nil

        // `Apphud.start`'s callback unwraps the customer: it must not run before there is one.
        await registerVersion1(launch, answering: FailingProtocol.self, released: false)

        XCTAssertTrue(launch.version1LaunchRegistrationEnded, "a registration did fail meanwhile")
    }

    @MainActor
    func testACachedCustomerIsRegisteredOnVersion1AsInSDK46() async {
        let (launch, cleanUp) = launchAfterVersion2(.v1, takeover: false)
        defer { cleanUp() }

        let performed = await isPerformed(launch)

        XCTAssertTrue(performed)
    }

    @MainActor
    func testVersion2NeverWaitsForARegistrationOfVersion1() async {
        let (launch, cleanUp) = launchAfterVersion2(.v2, takeover: true)
        defer { cleanUp() }

        let performed = await isPerformed(launch)

        XCTAssertTrue(performed)
    }

    func testRequestsCarryTheDeviceIDAndTheUserIDWhereSDK46SentIt() {
        XCTAssertEqual(sdk.currentUserID, "USER-1")
        XCTAssertEqual(sdk.identityParams(), ["device_id": "DEVICE-1"])
        XCTAssertEqual(sdk.identityParams(includeUserID: true), ["device_id": "DEVICE-1", "user_id": "USER-1"])
    }

    func testSubscriptionsCarryNoRestoreAndNoLegacyDeviceID() {
        XCTAssertEqual(sdk.subscriptionIdentityParams(restore: true) as NSDictionary, ["device_id": "DEVICE-1", "user_id": "USER-1"])
        XCTAssertEqual(sdk.subscriptionIdentityParams(restore: false) as NSDictionary, ["device_id": "DEVICE-1", "user_id": "USER-1"])
    }

    @MainActor
    func testCustomersBodyCarriesTheDeviceIDAndNoVersion2IDs() {
        sdk.isRedownload = false

        let params = sdk.customerRequestParams(fields: ["user_id": "USER-1", "initial_call": true])

        XCTAssertEqual(params["device_id"] as? String, "DEVICE-1")
        XCTAssertEqual(params["user_id"] as? String, "USER-1")
        XCTAssertEqual(params["initial_call"] as? Bool, true)
        for key in ["installation_id", "anonymous_id", "legacy_device_id", "restore", "reinstall"] {
            XCTAssertNil(params[key], key)
        }
    }

    @MainActor
    func testReinstallGoesInOneRegistrationPerProcess() {
        sdk.isRedownload = true
        sdk.reinstallTracked = false

        XCTAssertEqual(sdk.customerRequestParams(fields: [:])["reinstall"] as? Bool, true)
        XCTAssertNil(sdk.customerRequestParams(fields: [:])["reinstall"])
    }

    func testAPIVersionsAreThoseOfSDK46() {
        let expected: [(ApphudHttpClient.ApphudEndpoint, ApphudHttpClient.ApphudApiVersion)] = [
            (.customers, .APIV1), (.push, .APIV1), (.subscriptions, .APIV1), (.signOffer, .APIV1), (.promotions, .APIV1),
            (.properties, .APIV1), (.receipt, .APIV1), (.paywalls, .APIV1), (.rule("r"), .APIV1),
            (.events, .APIV2), (.notifications, .APIV2), (.readNotifications, .APIV2), (.screens, .APIV2),
            (.attribution, .APIV2), (.attributionDeeplink, .APIV2), (.renderProductProperties, .APIV2), (.paywall("p"), .APIV2),
            (.products, .APIV3), (.logs, .APIV3)
        ]
        for (endpoint, version) in expected {
            XCTAssertEqual(endpoint.v1APIVersion, version, endpoint.value)
        }
    }

    func testRequestsGoToTheVersion1APIWhateverTheCallerAsks() {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [RecordingProtocol.self]
        ApphudHttpClient.testURLSessionConfiguration = configuration
        defer { ApphudHttpClient.testURLSessionConfiguration = nil }
        RecordingProtocol.reset()
        let client = ApphudHttpClient()

        for (endpoint, method) in [(ApphudHttpClient.ApphudEndpoint.customers, ApphudHttpClient.ApphudHttpMethod.post), (.events, .post), (.products, .get)] {
            let done = expectation(description: endpoint.value)
            client.startRequest(path: endpoint, apiVersion: .APIV4, params: ["key": "value"], method: method) { _, _, _, _, _, _, _ in
                done.fulfill()
            }
            wait(for: [done], timeout: 5)
        }

        XCTAssertEqual(RecordingProtocol.urls.map(\.path), ["/v1/customers", "/v2/events", "/v3/products"])
    }

    func testPromoOfferParamsAreThoseOfSDK461() {
        let token = UUID(uuidString: "2F8AE6A1-B7C5-4966-8DF8-89F750012506")

        let params = ApphudInternal.promoOfferSignParamsV1(productID: "p", discountID: "d", appAccountToken: token, deviceID: "D", userID: "U")
        let noToken = ApphudInternal.promoOfferSignParamsV1(productID: "p", discountID: "d", appAccountToken: nil, deviceID: "D", userID: "U")

        XCTAssertEqual(params as NSDictionary, ["product_id": "p", "offer_id": "d", "application_username": "2f8ae6a1-b7c5-4966-8df8-89f750012506",
                                                "device_id": "D", "user_id": "U"])
        XCTAssertEqual(noToken["application_username"] as? String, "")
    }

    func testSignOfferSendsTheParamsOfSDK461() {
        let token = UUID(uuidString: "2F8AE6A1-B7C5-4966-8DF8-89F750012506")

        let params = sdk.signOfferParams(productID: "p", discountID: "d", appAccountToken: token)

        XCTAssertEqual(params as NSDictionary, ["product_id": "p", "offer_id": "d", "application_username": "2f8ae6a1-b7c5-4966-8df8-89f750012506",
                                                "device_id": "DEVICE-1", "user_id": "USER-1"])
    }

    func testApplicationUsernameIsAUUIDUserIDOtherwiseTheDeviceID() {
        let uuid = "2F8AE6A1-B7C5-4966-8DF8-89F750012506"

        sdk.v1UserID = uuid
        XCTAssertEqual(ApphudStoreKitWrapper.applicationUsername(), uuid)
        sdk.v1UserID = "alice"
        XCTAssertEqual(ApphudStoreKitWrapper.applicationUsername(), "DEVICE-1")
    }

    @MainActor
    func testNoTransactionIsAnotherAccountsInVersion1() {
        let key = ApphudStoreKitWrapper.purchaseUserTokensKey
        let savedTokens = UserDefaults.standard.object(forKey: key)
        defer { UserDefaults.standard.set(savedTokens, forKey: key) }
        let alice = UUID(uuidString: "2F8AE6A1-B7C5-4966-8DF8-89F750012506")!
        ApphudStoreKitWrapper.rememberPurchaseToken(alice, identity: ApphudIdentity(installationID: "inst-1", anonymousID: "anon-1", userID: alice.uuidString))

        sdk.identityVersion = .v2
        XCTAssertTrue(sdk.isAnotherAccountsToken(alice), "version 2 skips it: user-2 is signed in")
        sdk.identityVersion = .v1
        XCTAssertFalse(sdk.isAnotherAccountsToken(alice))
    }

    func testPreviewScreenURLCarriesTheDeviceIDAsSDK461() throws {
        let url = try XCTUnwrap(ApphudHttpClient.shared.makeScreenRequest(screenID: "screen")?.url?.absoluteString)

        XCTAssertTrue(url.contains("&device_id=DEVICE-1&v=2"), url)
        XCTAssertFalse(url.contains("installation_id"), url)
        XCTAssertFalse(url.contains("anonymous_id"), url)
    }

    func testAppAccountTokenOnlyOnceTheStoreKit1QueueIsSwizzled() {
        sdk.v1UserID = "2F8AE6A1-B7C5-4966-8DF8-89F750012506"
        // Version 2 would put this installation id into every purchase.
        sdk.identity = ApphudIdentity(installationID: "6F9619FF-8B86-D011-B42D-00C04FC964FF", anonymousID: "anon-1")
        let wrapper = ApphudStoreKitWrapper.shared
        // The unit tests never swizzle the queue: SDK 4.6 set no token then.
        XCTAssertNil(wrapper.appropriateApplicationUsername())

        XCTAssertNil(wrapper.appAccountToken())
    }

    @MainActor
    func testVersion2IDsAreEmptyAndDeviceIDIsTheDeviceID() {
        XCTAssertEqual(Apphud.installationID(), "")
        XCTAssertEqual(Apphud.anonymousID(), "")
        XCTAssertNil(Apphud.isReinstall())
        XCTAssertEqual(Apphud.deviceID(), "DEVICE-1")
        XCTAssertEqual(Apphud.userID(), "USER-1")
    }

    /// The system IDFV exists on iOS: the simulator run checks it.
    @MainActor
    func testNoSystemIDFV() {
        let savedIdentifiers = sdk.deviceIdentifiers
        defer { sdk.deviceIdentifiers = savedIdentifiers }
        sdk.deviceIdentifiers = (nil, nil)

        XCTAssertNil(apphudIdentifierForVendor())
    }

    func testDurationLogsNameTheSDK46Endpoints() {
        XCTAssertEqual(ApphudLoggerService.DurationLog.customers.endpoint, "/v1/customers")
        XCTAssertEqual(ApphudLoggerService.DurationLog.products.endpoint, "/v2/products")
        XCTAssertEqual(ApphudLoggerService.DurationLog.paywallConfigs.endpoint, "/v2/paywall_configs")
        XCTAssertEqual(ApphudLoggerService.DurationLog.subscriptions.endpoint, "/v1/subscriptions")

        sdk.identityVersion = .v2
        XCTAssertEqual(ApphudLoggerService.DurationLog.customers.endpoint, "/v4/customers")
    }
}
