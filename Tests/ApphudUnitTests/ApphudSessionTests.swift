//
//  ApphudSessionTests.swift
//  ApphudUnitTests
//
//  Client-side session id: boundaries, external mode and the request header.
//

import XCTest
#if os(macOS)
import AppKit
#elseif os(watchOS)
import WatchKit
#elseif canImport(UIKit)
import UIKit
#endif
@testable import ApphudSDK

private let uuidPattern = "^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$"

private func assertLowercaseUUID(_ value: String?, file: StaticString = #filePath, line: UInt = #line) {
    XCTAssertNotNil(value?.range(of: uuidPattern, options: .regularExpression), "\(value ?? "nil") is not a lowercase UUID", file: file, line: line)
}

/// Waits for the session's queued UserDefaults writes; fails instead of hanging.
private func flush(_ session: ApphudSession, file: StaticString = #filePath, line: UInt = #line) {
    let finished = DispatchSemaphore(value: 0)
    DispatchQueue.global().async {
        session.waitForPendingWrites()
        finished.signal()
    }
    if finished.wait(timeout: .now() + 3) == .timedOut {
        XCTFail("queued UserDefaults writes did not finish", file: file, line: line)
    }
}

private final class TestClock: @unchecked Sendable {
    var date = Date(timeIntervalSince1970: 1_800_000_000)
}

final class ApphudSessionTests: XCTestCase {

    private var suiteName = ""
    private var defaults: UserDefaults!
    private var clock: TestClock!
    private var center: NotificationCenter!
    private var launched: [ApphudSession] = []

    override func setUp() {
        super.setUp()
        suiteName = "ApphudSessionTests.\(UUID().uuidString)"
        defaults = UserDefaults(suiteName: suiteName)
        clock = TestClock()
        center = NotificationCenter()
        launched = []
    }

    override func tearDown() {
        launched.forEach { flush($0) }
        defaults.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    /// A new process over the same storage: writes of the previous ones have landed.
    private func launch() -> ApphudSession {
        launched.forEach { flush($0) }
        let clock = self.clock!
        let session = ApphudSession(defaults: defaults, now: { clock.date }, notificationCenter: center)
        launched.append(session)
        return session
    }

    private func background(_ session: ApphudSession, for seconds: TimeInterval) {
        session.didEnterBackground()
        clock.date.addTimeInterval(seconds)
        session.willEnterForeground()
    }

    // MARK: Default mode

    func testLaunchStartsSessionWithLowercaseUUID() {
        let session = launch()

        assertLowercaseUUID(session.sessionId)
        XCTAssertEqual(session.sessionNumber, 1)
    }

    func testRelaunchStartsNewSessionAndKeepsCounting() {
        let first = launch()
        let second = launch()

        XCTAssertNotEqual(first.sessionId, second.sessionId)
        XCTAssertEqual(second.sessionNumber, 2)
    }

    func testBackgroundOverThirtyMinutesStartsNewSession() {
        let session = launch()
        let id = session.sessionId

        background(session, for: 30 * 60 + 1)

        XCTAssertNotEqual(session.sessionId, id)
        assertLowercaseUUID(session.sessionId)
        XCTAssertEqual(session.sessionNumber, 2)
    }

    func testBackgroundOfExactlyThirtyMinutesKeepsSession() {
        let session = launch()
        let id = session.sessionId

        background(session, for: 30 * 60)

        XCTAssertEqual(session.sessionId, id)
        XCTAssertEqual(session.sessionNumber, 1)
    }

    func testShortBackgroundKeepsSession() {
        let session = launch()
        let id = session.sessionId

        background(session, for: 60)

        XCTAssertEqual(session.sessionId, id)
        XCTAssertEqual(session.sessionNumber, 1)
    }

    func testClockMovedBackKeepsSession() {
        let session = launch()
        let id = session.sessionId

        background(session, for: -3600)

        XCTAssertEqual(session.sessionId, id)
        XCTAssertEqual(session.sessionNumber, 1)
    }

    func testForegroundWithoutBackgroundKeepsSession() {
        let session = launch()
        let id = session.sessionId

        clock.date.addTimeInterval(2 * 3600)
        session.willEnterForeground()

        XCTAssertEqual(session.sessionId, id)
    }

    func testRepeatedBackgroundCountsFromTheFirstOne() {
        let session = launch()
        let id = session.sessionId

        session.didEnterBackground()
        clock.date.addTimeInterval(1000)
        session.didEnterBackground()
        clock.date.addTimeInterval(900)
        session.willEnterForeground()

        XCTAssertNotEqual(session.sessionId, id)
    }

    func testPreviousProcessBackgroundDateIsNotCompared() {
        let first = launch()
        first.didEnterBackground()
        clock.date.addTimeInterval(2 * 3600)

        let second = launch()
        let id = second.sessionId
        second.willEnterForeground()

        XCTAssertEqual(second.sessionId, id)
        XCTAssertEqual(second.sessionNumber, 2)
    }

    func testLaunchedInBackgroundCountsFromLaunch() {
        let session = launch()
        let id = session.sessionId

        session.markLaunchedInBackground()
        clock.date.addTimeInterval(30 * 60 + 1)
        session.willEnterForeground()

        XCTAssertNotEqual(session.sessionId, id)
    }

    func testLogoutStartsNewSessionAndNumberSurvivesRelaunch() {
        let session = launch()
        let id = session.sessionId

        session.startNewSessionOnLogout()

        XCTAssertNotEqual(session.sessionId, id)
        assertLowercaseUUID(session.sessionId)
        XCTAssertEqual(session.sessionNumber, 2)
        XCTAssertEqual(launch().sessionNumber, 3)
    }

    func testLifecycleNotificationsDriveSession() {
        #if os(macOS)
        // macOS has no background state: an inactive app counts as backgrounded.
        let background = NSApplication.didResignActiveNotification
        let foreground = NSApplication.didBecomeActiveNotification
        #elseif os(watchOS)
        let background = WKApplication.didEnterBackgroundNotification
        let foreground = WKApplication.willEnterForegroundNotification
        #else
        let background = UIApplication.didEnterBackgroundNotification
        let foreground = UIApplication.willEnterForegroundNotification
        #endif
        let session = launch()
        let id = session.sessionId

        center.post(name: background, object: nil)
        clock.date.addTimeInterval(30 * 60 + 1)
        center.post(name: foreground, object: nil)

        XCTAssertNotEqual(session.sessionId, id)
        XCTAssertEqual(session.sessionNumber, 2)
    }

    func testBackgroundDateIsPersistedAndSurvivesLogout() {
        let session = launch()
        session.didEnterBackground()
        let date = clock.date
        session.startNewSessionOnLogout()
        let relaunched = launch()
        flush(relaunched)

        XCTAssertEqual(defaults.object(forKey: "ApphudSessionLastBackgroundDate") as? Date, date)
    }

    // MARK: External mode

    func testExternalIdIsSentLowercase() {
        let session = launch()

        session.setExternalSessionId("E621E1F8-C36C-495A-93FC-0C247A3E6E5F")

        XCTAssertEqual(session.sessionId, "e621e1f8-c36c-495a-93fc-0c247a3e6e5f")
    }

    func testExternalModeIgnoresBackgroundAndLogout() {
        let session = launch()
        session.setExternalSessionId("e621e1f8-c36c-495a-93fc-0c247a3e6e5f")
        let number = session.sessionNumber

        background(session, for: 30 * 60 + 1)
        session.startNewSessionOnLogout()

        XCTAssertEqual(session.sessionId, "e621e1f8-c36c-495a-93fc-0c247a3e6e5f")
        XCTAssertEqual(session.sessionNumber, number)

        session.setExternalSessionId("0b1c2d3e-4f50-4617-8293-a4b5c6d7e8f9")

        XCTAssertEqual(session.sessionId, "0b1c2d3e-4f50-4617-8293-a4b5c6d7e8f9")
        XCTAssertEqual(session.sessionNumber, number)
    }

    func testInvalidExternalIdIsIgnored() {
        let session = launch()
        let id = session.sessionId

        for value in ["", "not-a-uuid", " e621e1f8-c36c-495a-93fc-0c247a3e6e5f", "e621e1f8c36c495a93fc0c247a3e6e5f"] {
            session.setExternalSessionId(value)
            XCTAssertEqual(session.sessionId, id, "\"\(value)\" must be ignored")
        }

        // Still in default mode: the SDK keeps its own boundaries.
        background(session, for: 30 * 60 + 1)
        XCTAssertNotEqual(session.sessionId, id)
    }

    // MARK: Threads

    func testConcurrentReadsAndBoundaries() {
        let session = launch()
        let lock = NSLock()
        var ids: [String] = []

        DispatchQueue.concurrentPerform(iterations: 4000) { index in
            switch index % 4 {
            case 0: session.didEnterBackground()
            case 1: session.willEnterForeground()
            case 2: session.startNewSessionOnLogout()
            default:
                let id = session.sessionId
                lock.lock()
                ids.append(id)
                lock.unlock()
            }
        }

        XCTAssertEqual(ids.count, 1000)
        ids.forEach { assertLowercaseUUID($0) }
        XCTAssertEqual(session.sessionNumber, 1001)
    }

    func testConcurrentExternalIdsAndReads() {
        let session = launch()
        let hostIds = (0..<8).map { _ in UUID().uuidString }
        let lock = NSLock()
        var ids: [String] = []

        DispatchQueue.concurrentPerform(iterations: 2000) { index in
            if index % 2 == 0 {
                session.setExternalSessionId(hostIds[index % hostIds.count])
            } else {
                let id = session.sessionId
                lock.lock()
                ids.append(id)
                lock.unlock()
            }
        }

        ids.forEach { assertLowercaseUUID($0) }
        XCTAssertTrue(hostIds.map { $0.lowercased() }.contains(session.sessionId))
    }

    func testHostReadingSessionInsideDefaultsNotificationDoesNotHang() {
        let session = launch()
        flush(session)
        let hostRead = expectation(description: "a host observer read the session id inside UserDefaults' change notification")
        hostRead.expectedFulfillmentCount = 2 // the background date and the logout number
        hostRead.assertForOverFulfill = false
        let token = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: defaults, queue: nil) { _ in
            _ = session.sessionId
            hostRead.fulfill()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        let returned = expectation(description: "background and logout boundaries returned")
        DispatchQueue.global().async {
            session.didEnterBackground()
            session.startNewSessionOnLogout()
            returned.fulfill()
        }

        wait(for: [returned, hostRead], timeout: 3)
    }

    func testLaunchDoesNotWriteDefaultsOnTheCallingThread() {
        // A write inside init would post didChangeNotification inside `ApphudSession.shared`'s
        // initializer, where a host observer reading `Apphud.sessionId` would re-enter it.
        let caller = Thread.current
        let lock = NSLock()
        var postedOnCaller = false
        let token = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: defaults, queue: nil) { _ in
            guard Thread.current == caller else { return }
            lock.lock()
            postedOnCaller = true
            lock.unlock()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        flush(launch())

        lock.lock(); defer { lock.unlock() }
        XCTAssertFalse(postedOnCaller)
    }
}

// MARK: - Request header

private final class SessionStubProtocol: URLProtocol {

    struct Recorded {
        let url: URL?
        let sessionHeader: String?
        let idempotencyKey: String?
    }

    private static let lock = NSLock()
    private static var _recorded: [Recorded] = []
    private static var statuses: [Int] = []
    private static var onRequest: ((Int) -> Void)?

    static var recorded: [Recorded] {
        lock.lock(); defer { lock.unlock() }
        return _recorded
    }

    static func reset(statuses: [Int] = [], onRequest: ((Int) -> Void)? = nil) {
        lock.lock(); defer { lock.unlock() }
        _recorded = []
        self.statuses = statuses
        self.onRequest = onRequest
    }

    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }

    override func startLoading() {
        Self.lock.lock()
        Self._recorded.append(Recorded(url: request.url,
                                       sessionHeader: request.value(forHTTPHeaderField: ApphudSession.headerName),
                                       idempotencyKey: request.value(forHTTPHeaderField: "Idempotency-Key")))
        let index = Self._recorded.count - 1
        let status = index < Self.statuses.count ? Self.statuses[index] : 200
        let hook = Self.onRequest
        Self.lock.unlock()

        hook?(index)

        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: Data("{}".utf8))
        client?.urlProtocolDidFinishLoading(self)
    }

    override func stopLoading() {}
}

final class ApphudSessionHeaderTests: XCTestCase {

    private var suiteName = ""
    private var originalSession: ApphudSession!
    private var client: ApphudHttpClient!

    override func setUp() {
        super.setUp()
        suiteName = "ApphudSessionHeaderTests.\(UUID().uuidString)"
        originalSession = ApphudSession.shared
        ApphudSession.shared = ApphudSession(defaults: UserDefaults(suiteName: suiteName)!, notificationCenter: NotificationCenter())

        let configuration = URLSessionConfiguration.ephemeral
        configuration.protocolClasses = [SessionStubProtocol.self]
        ApphudHttpClient.testURLSessionConfiguration = configuration
        client = ApphudHttpClient()
        SessionStubProtocol.reset()
    }

    override func tearDown() {
        ApphudHttpClient.testURLSessionConfiguration = nil
        flush(ApphudSession.shared)
        ApphudSession.shared = originalSession
        UserDefaults(suiteName: suiteName)?.removePersistentDomain(forName: suiteName)
        super.tearDown()
    }

    private func send(_ path: ApphudHttpClient.ApphudEndpoint, method: ApphudHttpClient.ApphudHttpMethod, retry: Bool = false, requestID: String? = nil, timeout: TimeInterval = 5) {
        let done = expectation(description: "request answered")
        client.startRequest(path: path, params: method == .get ? nil : ["key": "value"], method: method, retry: retry, requestID: requestID) { _, _, _, _, _, _, _ in
            done.fulfill()
        }
        wait(for: [done], timeout: timeout)
    }

    func testApiRequestsCarrySessionHeader() {
        send(.customers, method: .post)
        send(.products, method: .get)

        let recorded = SessionStubProtocol.recorded
        XCTAssertEqual(recorded.count, 2)
        for request in recorded {
            XCTAssertEqual(request.sessionHeader, ApphudSession.shared.sessionId)
            assertLowercaseUUID(request.sessionHeader)
        }
    }

    func testScreenHtmlRequestCarriesSessionHeader() {
        let request = client.makeScreenRequest(screenID: "screen")

        XCTAssertEqual(request?.value(forHTTPHeaderField: ApphudSession.headerName), ApphudSession.shared.sessionId)
    }

    func testRetriedRequestKeepsItsSessionId() {
        let original = ApphudSession.shared.sessionId
        SessionStubProtocol.reset(statuses: [500, 200]) { index in
            if index == 0 { ApphudSession.shared.startNewSessionOnLogout() }
        }

        send(.customers, method: .post, retry: true, timeout: 10)

        let recorded = SessionStubProtocol.recorded
        XCTAssertEqual(recorded.count, 2)
        XCTAssertEqual(recorded.map(\.sessionHeader), [original, original])
        XCTAssertNotEqual(ApphudSession.shared.sessionId, original)
    }

    func testResentRegistrationWithSameIdempotencyKeyTakesCurrentSession() {
        send(.customers, method: .post, requestID: "initial-registration")
        ApphudSession.shared.startNewSessionOnLogout()
        send(.customers, method: .post, requestID: "initial-registration")

        let recorded = SessionStubProtocol.recorded
        XCTAssertEqual(recorded.count, 2)
        XCTAssertEqual(recorded.map(\.idempotencyKey), ["initial-registration", "initial-registration"])
        XCTAssertNotEqual(recorded[0].sessionHeader, recorded[1].sessionHeader)
        XCTAssertEqual(recorded[1].sessionHeader, ApphudSession.shared.sessionId)
    }

    func testSetSessionIdBeforeFirstRequestReachesRegistration() {
        Apphud.setSessionId("E621E1F8-C36C-495A-93FC-0C247A3E6E5F")

        XCTAssertEqual(Apphud.sessionId, "e621e1f8-c36c-495a-93fc-0c247a3e6e5f")

        send(.customers, method: .post)

        XCTAssertEqual(SessionStubProtocol.recorded.first?.sessionHeader, "e621e1f8-c36c-495a-93fc-0c247a3e6e5f")
    }

    func testNonApphudRequestsDoNotCarrySessionHeader() async {
        URLProtocol.registerClass(SessionStubProtocol.self)
        defer { URLProtocol.unregisterClass(SessionStubProtocol.self) }

        _ = await ApphudInternal.shared.getAppleAttribution("token")
        _ = await client.loadFallbackHostIfNeeded()

        let hosts = ["api-adservices.apple.com", "apphud.blob.core.windows.net"]
        for host in hosts {
            let requests = SessionStubProtocol.recorded.filter { $0.url?.host == host }
            XCTAssertFalse(requests.isEmpty, "no request to \(host) was made")
            XCTAssertTrue(requests.allSatisfy { $0.sessionHeader == nil }, "\(host) must not get the session header")
        }
    }

    #if os(iOS) && targetEnvironment(simulator)
    // Simulator only: a full logout resets the Keychain, which on macOS is the login keychain.
    func testLogoutStartsNewSession() async {
        let session = ApphudSession.shared
        let id = session.sessionId
        let number = session.sessionNumber

        await ApphudInternal.shared.logout()

        XCTAssertNotEqual(session.sessionId, id)
        XCTAssertEqual(session.sessionNumber, number + 1)
    }
    #endif
}
