import XCTest
@testable import ApphudSDK

/// Holds each products request, so a test answers it.
private final class GroupsHTTPClient: ApphudHttpClient {
    @MainActor var productRequests: [ApphudHTTPResponseCallback?] = []
    override var canRetry: Bool { false }

    override func startRequest(path: ApphudEndpoint, apiVersion: ApphudApiVersion = .APIV4,
                               params: [String: Any]?, method: ApphudHttpMethod,
                               useDecoder: Bool = false, retry: Bool = false,
                               requestID: String? = nil, callback: ApphudHTTPResponseCallback?) {
        Task { @MainActor in
            guard path == .products else {
                callback?(true, nil, nil, nil, 200, 0, 0)
                return
            }
            productRequests.append(callback)
        }
    }
}

/// The cached products groups at launch: shown at once, refreshed when expired (APPHUD-1595).
@MainActor
final class ApphudPermissionGroupsTests: XCTestCase {

    private let timeout: TimeInterval = 3_600

    private var cacheFile: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0].appendingPathComponent("ApphudProductGroups")
    }

    override func setUp() async throws {
        try await super.setUp()
        let url = cacheFile
        let saved = try? Data(contentsOf: url)
        let created = (try? FileManager.default.attributesOfItem(atPath: url.path))?[.creationDate] as? Date
        try? FileManager.default.removeItem(at: url)
        addTeardownBlock {
            try? FileManager.default.removeItem(at: url)
            guard let saved else { return }
            try saved.write(to: url)
            if let created { try FileManager.default.setAttributes([.creationDate: created], ofItemAtPath: url.path) }
        }
    }

    // MARK: - Cases

    func testFreshCacheIsReusedWithoutARequest() async throws {
        try await cache(["Premium"], age: 60)
        let (sdk, client) = try launch()

        sdk.restorePermissionGroups(await sdk.cachedGroups())
        try await settle()

        XCTAssertEqual(sdk.permissionGroups?.map(\.name), ["Premium"])
        XCTAssertEqual(client.productRequests.count, 0)
    }

    func testExpiredCacheIsShownThenRefreshedInMemoryAndOnDisk() async throws {
        for version in [ApphudIdentityVersion.v1, .v2] {
            try await cache(["Premium"], age: timeout * 2)
            let (sdk, client) = try launch(version)

            sdk.restorePermissionGroups(await sdk.cachedGroups())
            XCTAssertEqual(sdk.permissionGroups?.map(\.name), ["Premium"], "the cached groups don't wait for the backend")
            let requested = await until { client.productRequests.count == 1 }
            XCTAssertTrue(requested, "\(version)")

            try respond(client, groups: ["Premium", "Ultra"])
            let refreshed = await until { sdk.permissionGroups?.map(\.name) == ["Premium", "Ultra"] }

            XCTAssertTrue(refreshed, "\(version)")
            let stored = await sdk.cachedGroups()
            XCTAssertEqual(stored.objects?.map(\.name), ["Premium", "Ultra"])
            XCTAssertFalse(stored.expired)
        }
    }

    func testFailedRefreshKeepsTheCacheExpiredAndTheNextLaunchRetries() async throws {
        try await cache(["Premium"], age: timeout * 2)
        let written = try creationDate()
        let (sdk, client) = try launch()
        sdk.restorePermissionGroups(await sdk.cachedGroups())
        let requested = await until { client.productRequests.count == 1 }
        XCTAssertTrue(requested)

        // A failed request can still carry a body that decodes.
        try respond(client, groups: ["Ultra"], error: ApphudError(message: "offline"))
        try await settle()

        XCTAssertEqual(sdk.permissionGroups?.map(\.name), ["Premium"])
        let stored = await sdk.cachedGroups()
        XCTAssertEqual(stored.objects?.map(\.name), ["Premium"])
        XCTAssertTrue(stored.expired)
        XCTAssertEqual(try creationDate(), written)

        let (nextLaunch, nextClient) = try launch()
        nextLaunch.restorePermissionGroups(await nextLaunch.cachedGroups())
        let retried = await until { nextClient.productRequests.count == 1 }
        XCTAssertTrue(retried)
    }

    func testCleanInstallFetchesNothingAtLaunch() async throws {
        let (sdk, client) = try launch()

        sdk.restorePermissionGroups(await sdk.cachedGroups())
        try await settle()

        XCTAssertNil(sdk.permissionGroups, "nil keeps the lazy fetch of the first call that needs the groups")
        XCTAssertEqual(client.productRequests.count, 0)
    }

    // MARK: - Helpers

    private func launch(_ version: ApphudIdentityVersion = .v2) throws -> (ApphudInternal, GroupsHTTPClient) {
        let name = "ApphudPermissionGroupsTests.\(UUID().uuidString)"
        let defaults = try XCTUnwrap(UserDefaults(suiteName: name))
        let sdk = ApphudInternal()
        sdk.identityVersion = version
        sdk.identityStore = ApphudIdentityStore(defaults: defaults)
        sdk.cacheTimeout = timeout
        let client = GroupsHTTPClient()
        sdk.httpClient = client
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        sdk.currentUser = try decoder.decode(ApphudUser.self, from: Data(#"{"id":"customer","user_id":"user","subscriptions":[]}"#.utf8))
        addTeardownBlock { defaults.removePersistentDomain(forName: name) }
        return (sdk, client)
    }

    private func groupsJSON(_ names: [String]) -> [[String: Any]] {
        names.map { name in
            ["id": "group_\(name)", "name": name,
             "bundles": [["id": "bundle_\(name)", "item_id": "item_\(name)", "name": name, "store": "app_store",
                          "product_id": "com.apphud.\(name)"]]]
        }
    }

    private func cache(_ names: [String], age: TimeInterval) async throws {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        let groups = try decoder.decode([ApphudGroup].self, from: JSONSerialization.data(withJSONObject: groupsJSON(names)))
        await ApphudInternal().cacheGroups(groups: groups)
        try FileManager.default.setAttributes([.creationDate: Date().addingTimeInterval(-age)], ofItemAtPath: cacheFile.path)
    }

    private func respond(_ client: GroupsHTTPClient, groups: [String], error: Error? = nil) throws {
        let data = try JSONSerialization.data(withJSONObject: ["data": ["results": groupsJSON(groups)]])
        client.productRequests[0]?(error == nil, nil, data, error, error == nil ? 200 : 500, 0, 0)
    }

    private func creationDate() throws -> Date {
        try XCTUnwrap(FileManager.default.attributesOfItem(atPath: cacheFile.path)[.creationDate] as? Date)
    }

    /// Time for a request that must not happen, or an answer that must change nothing.
    private func settle() async throws {
        try await Task.sleep(nanoseconds: 300_000_000)
    }

    private func until(_ condition: @MainActor () -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(2)
        while !condition() && Date() < deadline { try? await Task.sleep(nanoseconds: 10_000_000) }
        return condition()
    }
}
