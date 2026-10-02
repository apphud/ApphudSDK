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

private final class TestFlag: @unchecked Sendable {
    var value = false
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

    /// A new process over the same storage: writes of the previous ones have landed. An
    /// `activated` launch comes to the foreground right away, like a user launch; otherwise it
    /// stays in the background, like a silent push.
    private func launch(activated: Bool = true, canPersist: @escaping () -> Bool = { true }) -> ApphudSession {
        launched.forEach { flush($0) }
        let clock = self.clock!
        let session = ApphudSession(defaults: defaults, now: { clock.date }, notificationCenter: center, canPersist: canPersist)
        if activated { session.willEnterForeground() }
        launched.append(session)
        return session
    }

    private func background(_ session: ApphudSession, for seconds: TimeInterval) {
        session.didEnterBackground()
        clock.date.addTimeInterval(seconds)
        session.willEnterForeground()
    }

    private var savedId: String? { defaults.string(forKey: "ApphudSessionId") }
    private var savedBackgroundDate: Date? { defaults.object(forKey: "ApphudSessionLastBackgroundDate") as? Date }

    /// The user used the app and sent it to the background; the process then ended.
    private func sessionSentToBackground() -> String {
        let session = launch()
        session.didEnterBackground()
        return session.sessionId
    }

    // MARK: Launch

    func testFirstLaunchStartsSavedSessionWithLowercaseUUID() {
        let launchDate = clock.date
        let session = launch()

        assertLowercaseUUID(session.sessionId)
        flush(session)
        XCTAssertEqual(savedId, session.sessionId)
        XCTAssertEqual(savedBackgroundDate, launchDate)
    }

    func testBackgroundLaunchWithinThirtyMinutesContinuesSession() {
        let id = sessionSentToBackground()
        clock.date.addTimeInterval(10 * 60)

        XCTAssertEqual(launch(activated: false).sessionId, id)
    }

    func testUserLaunchWithinThirtyMinutesStartsNewSession() {
        let id = sessionSentToBackground()
        clock.date.addTimeInterval(10 * 60)

        XCTAssertNotEqual(launch().sessionId, id)
    }

    func testRequestsBeforeTheFirstForegroundCarryTheStartSession() {
        // A cold launch by the user: a request sent before the first foreground signal, such as
        // the registration from `Apphud.start` when it goes out first, carries the start session.
        let id = sessionSentToBackground()
        clock.date.addTimeInterval(10 * 60)
        let session = launch(activated: false)
        XCTAssertEqual(session.sessionId, id)

        session.willEnterForeground()

        XCTAssertNotEqual(session.sessionId, id)
    }

    func testLaunchAtExactlyThirtyMinutesContinuesSession() {
        let id = sessionSentToBackground()
        clock.date.addTimeInterval(30 * 60)

        XCTAssertEqual(launch(activated: false).sessionId, id)
    }

    func testLaunchAfterThirtyMinutesStartsNewSessionFromLaunch() {
        let id = sessionSentToBackground()
        clock.date.addTimeInterval(30 * 60 + 1)
        let launchDate = clock.date

        let session = launch(activated: false)
        flush(session)

        XCTAssertNotEqual(session.sessionId, id)
        assertLowercaseUUID(session.sessionId)
        XCTAssertEqual(savedId, session.sessionId)
        XCTAssertEqual(savedBackgroundDate, launchDate)
    }

    func testLaunchWithSavedDateInTheFutureStartsNewSession() {
        let id = sessionSentToBackground()
        clock.date.addTimeInterval(-60)

        XCTAssertNotEqual(launch(activated: false).sessionId, id)
    }

    func testLaunchesDoNotExtendSession() {
        let id = sessionSentToBackground()
        clock.date.addTimeInterval(20 * 60)
        XCTAssertEqual(launch(activated: false).sessionId, id)

        clock.date.addTimeInterval(15 * 60)

        XCTAssertNotEqual(launch(activated: false).sessionId, id)
    }

    func testSessionStartedAtLaunchContinuesOnNextLaunch() {
        _ = sessionSentToBackground()
        clock.date.addTimeInterval(2 * 3600)
        let id = launch(activated: false).sessionId

        clock.date.addTimeInterval(10 * 60)

        XCTAssertEqual(launch(activated: false).sessionId, id)
    }

    func testUserOpenAfterBackgroundLaunchStartsNewSession() {
        let id = sessionSentToBackground()
        clock.date.addTimeInterval(10 * 60)
        let session = launch(activated: false)

        clock.date.addTimeInterval(5 * 60)
        session.willEnterForeground()

        XCTAssertNotEqual(session.sessionId, id)
    }

    func testFirstForegroundSignalsStartOneSession() {
        let names = ApphudSession.lifecycleNotificationNames.foreground
        let session = launch(activated: false)
        let startId = session.sessionId

        center.post(name: names.first!, object: nil)
        let id = session.sessionId
        center.post(name: names.last!, object: nil)

        XCTAssertNotEqual(id, startId)
        XCTAssertEqual(session.sessionId, id)
    }

    func testActiveAppIsNotInTheBackground() {
        let session = launch()
        let id = session.sessionId
        flush(session)
        let date = savedBackgroundDate

        clock.date.addTimeInterval(2 * 3600)
        session.willEnterForeground()
        session.didEnterBackground()
        flush(session)

        XCTAssertEqual(session.sessionId, id)
        XCTAssertNotEqual(savedBackgroundDate, date)
    }

    func testBecomingActiveAtLaunchCountsAsTheFirstForeground() {
        // A cold launch may post only didBecomeActive (a separate observer on iOS, the only
        // foreground signal on macOS): it starts the session, and a later foreground signal
        // without a background in between doesn't rotate it.
        let foreground = ApphudSession.lifecycleNotificationNames.foreground
        let session = launch(activated: false)
        let startId = session.sessionId

        center.post(name: foreground.last!, object: nil)
        let id = session.sessionId
        clock.date.addTimeInterval(2 * 3600)
        center.post(name: foreground.first!, object: nil)

        XCTAssertNotEqual(id, startId)
        XCTAssertEqual(session.sessionId, id)
    }

    func testStartInAnActiveAppTakesTheForegroundAtOnce() {
        let session = launch(activated: false)
        let startId = session.sessionId
        session.takeForeground(ifActive: true)
        let id = session.sessionId
        XCTAssertNotEqual(id, startId)

        clock.date.addTimeInterval(40 * 60)
        session.didEnterBackground()
        let date = clock.date
        clock.date.addTimeInterval(60)
        session.willEnterForeground()
        flush(session)

        XCTAssertEqual(session.sessionId, id)
        XCTAssertEqual(savedBackgroundDate, date)
    }

    func testStartInAnInactiveAppWaitsForTheForegroundSignal() {
        let session = launch(activated: false)
        let id = session.sessionId

        session.takeForeground(ifActive: false)
        XCTAssertEqual(session.sessionId, id)

        session.willEnterForeground()
        XCTAssertNotEqual(session.sessionId, id)
    }

    // MARK: Background

    func testBackgroundOverThirtyMinutesStartsNewSession() {
        let session = launch()
        let id = session.sessionId

        background(session, for: 30 * 60 + 1)

        XCTAssertNotEqual(session.sessionId, id)
        assertLowercaseUUID(session.sessionId)
    }

    func testBackgroundOfExactlyThirtyMinutesKeepsSession() {
        let session = launch()
        let id = session.sessionId

        background(session, for: 30 * 60)

        XCTAssertEqual(session.sessionId, id)
    }

    func testShortBackgroundKeepsSession() {
        let session = launch()
        let id = session.sessionId

        background(session, for: 60)

        XCTAssertEqual(session.sessionId, id)
    }

    func testClockMovedBackKeepsSession() {
        let session = launch()
        let id = session.sessionId

        background(session, for: -3600)

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

    func testBackgroundSavesIdAndDate() {
        let session = launch()
        clock.date.addTimeInterval(60)
        let date = clock.date

        session.didEnterBackground()
        flush(session)

        XCTAssertEqual(savedId, session.sessionId)
        XCTAssertEqual(savedBackgroundDate, date)
    }

    func testLogoutStartsNewSessionAndSavesIt() {
        let session = launch()
        let id = session.sessionId

        flush(session)
        let date = savedBackgroundDate
        clock.date.addTimeInterval(60)

        session.startNewSessionOnLogout()
        flush(session)

        XCTAssertNotEqual(session.sessionId, id)
        assertLowercaseUUID(session.sessionId)
        XCTAssertEqual(savedId, session.sessionId)
        XCTAssertEqual(savedBackgroundDate, date)
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
    }

    // MARK: Storage

    func testNothingIsReadOrSavedWhileStorageIsUnreadable() {
        let id = sessionSentToBackground()
        flush(launched[0])
        let date = savedBackgroundDate
        clock.date.addTimeInterval(5 * 60)

        let session = launch(activated: false, canPersist: { false })
        XCTAssertNotEqual(session.sessionId, id)

        session.willEnterForeground()
        session.didEnterBackground()
        session.startNewSessionOnLogout()
        flush(session)

        XCTAssertEqual(savedId, id)
        XCTAssertEqual(savedBackgroundDate, date)
    }

    func testSavingResumesWhenStorageBecomesReadable() {
        let flag = TestFlag()
        let session = launch(activated: false, canPersist: { flag.value })
        flush(session)
        XCTAssertNil(savedId)

        flag.value = true
        session.willEnterForeground()
        session.didEnterBackground()
        let date = clock.date
        flush(session)

        XCTAssertEqual(savedId, session.sessionId)
        XCTAssertEqual(savedBackgroundDate, date)
    }

    func testStorageIsReadableWithASavedSessionOrProtectedDataAvailable() {
        XCTAssertFalse(ApphudSession.isStorageReadable(defaults, protectedDataAvailable: { false }))
        XCTAssertTrue(ApphudSession.isStorageReadable(defaults, protectedDataAvailable: { true }))

        defaults.set("saved", forKey: "ApphudSessionId")

        XCTAssertTrue(ApphudSession.isStorageReadable(defaults, protectedDataAvailable: { false }))
    }

    // MARK: External mode

    func testAnyValidExternalIdIsKeptAsGivenAndEntersExternalMode() {
        for value in ["E621E1F8-C36C-495A-93FC-0C247A3E6E5F", "not-a-uuid", "Host Session-1"] {
            let session = launch()
            session.setExternalSessionId(value)

            background(session, for: 30 * 60 + 1)
            session.startNewSessionOnLogout()

            XCTAssertEqual(session.sessionId, value, "\"\(value)\"")
        }
    }

    func testExternalIdWithSurroundingWhitespaceIsTrimmed() {
        let session = launch()

        session.setExternalSessionId("  host-1 \t\n")

        XCTAssertEqual(session.sessionId, "host-1")
    }

    func testInvalidExternalIdIsIgnored() {
        for value in ["", "   ", "line\nbreak", "сессия"] {
            let session = launch()
            let id = session.sessionId

            session.setExternalSessionId(value)

            XCTAssertEqual(session.sessionId, id, "\"\(value)\"")
        }
    }

    func testInvalidExternalIdKeepsSDKBoundaries() {
        let session = launch()
        let id = session.sessionId
        session.setExternalSessionId("   ")

        background(session, for: 30 * 60 + 1)

        XCTAssertNotEqual(session.sessionId, id)
    }

    func testInvalidExternalIdKeepsHostId() {
        let session = launch()
        session.setExternalSessionId("host")

        session.setExternalSessionId("")

        XCTAssertEqual(session.sessionId, "host")
    }

    func testExternalModeIgnoresBackgroundAndLogout() {
        let session = launch()
        session.setExternalSessionId("e621e1f8-c36c-495a-93fc-0c247a3e6e5f")

        background(session, for: 30 * 60 + 1)
        session.startNewSessionOnLogout()

        XCTAssertEqual(session.sessionId, "e621e1f8-c36c-495a-93fc-0c247a3e6e5f")

        session.setExternalSessionId("0b1c2d3e-4f50-4617-8293-a4b5c6d7e8f9")

        XCTAssertEqual(session.sessionId, "0b1c2d3e-4f50-4617-8293-a4b5c6d7e8f9")
    }

    func testFirstForegroundKeepsTheHostId() {
        let session = launch(activated: false)
        flush(session)
        let ownId = savedId
        session.setExternalSessionId("host")

        session.willEnterForeground()
        flush(session)

        XCTAssertEqual(session.sessionId, "host")
        XCTAssertEqual(savedId, ownId)
    }

    func testExternalModeSavesNothing() {
        let session = launch()
        flush(session)
        let ownId = session.sessionId
        let date = savedBackgroundDate
        session.setExternalSessionId("host")

        clock.date.addTimeInterval(60)
        session.didEnterBackground()
        clock.date.addTimeInterval(30 * 60 + 1)
        session.willEnterForeground()
        session.startNewSessionOnLogout()
        flush(session)

        XCTAssertEqual(savedId, ownId)
        XCTAssertEqual(savedBackgroundDate, date)
    }

    // MARK: Threads

    func testConcurrentReadsAndBoundaries() {
        let session = launch()
        let launchId = session.sessionId
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
        XCTAssertNotEqual(session.sessionId, launchId)
        flush(session)
        XCTAssertEqual(savedId, session.sessionId)
    }

    func testConcurrentExternalIdsAndReads() {
        let session = launch()
        let launchId = session.sessionId
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

        let expected = Set(hostIds + [launchId])
        XCTAssertEqual(ids.count, 1000)
        XCTAssertTrue(ids.allSatisfy { expected.contains($0) })
        XCTAssertTrue(hostIds.contains(session.sessionId))
    }

    func testHostReadingSessionInsideDefaultsNotificationDoesNotHang() {
        let session = launch()
        flush(session)
        let hostRead = expectation(description: "a host observer read the session id inside UserDefaults' change notification")
        hostRead.expectedFulfillmentCount = 2 // the background id and date, then the logout id
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
        // initializer, where a host observer calling into the SDK would re-enter it.
        let caller = Thread.current
        let lock = NSLock()
        var posted = 0
        var postedOnCaller = false
        let token = NotificationCenter.default.addObserver(forName: UserDefaults.didChangeNotification, object: defaults, queue: nil) { _ in
            lock.lock()
            posted += 1
            if Thread.current == caller { postedOnCaller = true }
            lock.unlock()
        }
        defer { NotificationCenter.default.removeObserver(token) }

        flush(launch(activated: false))

        lock.lock(); defer { lock.unlock() }
        XCTAssertGreaterThan(posted, 0, "the launch write must reach UserDefaults")
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
        ApphudSession.shared = ApphudSession(defaults: UserDefaults(suiteName: suiteName)!, notificationCenter: NotificationCenter(), canPersist: { true })

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

    func testRegistrationBeforeTheFirstForegroundCarriesTheStartSession() {
        // A cold launch by the user where the registration from `Apphud.start` goes out before
        // the first foreground signal: it carries the session the process started with; later
        // requests carry the session the first foreground started.
        flush(ApphudSession.shared)
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.set("saved-session", forKey: "ApphudSessionId")
        defaults.set(Date().addingTimeInterval(-10 * 60), forKey: "ApphudSessionLastBackgroundDate")
        ApphudSession.shared = ApphudSession(defaults: defaults, notificationCenter: NotificationCenter(), canPersist: { true })

        send(.customers, method: .post)
        ApphudSession.shared.willEnterForeground()
        send(.customers, method: .post)

        let headers = SessionStubProtocol.recorded.map(\.sessionHeader)
        XCTAssertEqual(headers.count, 2)
        XCTAssertEqual(headers.first, "saved-session")
        XCTAssertNotEqual(headers.last, "saved-session")
        XCTAssertEqual(headers.last, ApphudSession.shared.sessionId)
    }

    func testSetSessionIdBeforeFirstRequestReachesRegistration() {
        Apphud.platform.setSessionId("E621E1F8-C36C-495A-93FC-0C247A3E6E5F")

        XCTAssertEqual(ApphudSession.shared.sessionId, "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")

        send(.customers, method: .post)

        XCTAssertEqual(SessionStubProtocol.recorded.first?.sessionHeader, "E621E1F8-C36C-495A-93FC-0C247A3E6E5F")
    }

    func testBlankSetSessionIdKeepsSessionId() {
        let id = Apphud.platform.sessionId

        Apphud.platform.setSessionId("  ")

        XCTAssertEqual(Apphud.platform.sessionId, id)
    }

    func testPlatformSessionIdMatchesRequestHeaderInBothModes() {
        // Default mode: the SDK's own id.
        send(.customers, method: .post)
        assertLowercaseUUID(Apphud.platform.sessionId)
        XCTAssertEqual(SessionStubProtocol.recorded.last?.sessionHeader, Apphud.platform.sessionId)

        // External mode: the host's value.
        Apphud.platform.setSessionId("host-session-1")
        send(.customers, method: .post)
        XCTAssertEqual(Apphud.platform.sessionId, "host-session-1")
        XCTAssertEqual(SessionStubProtocol.recorded.last?.sessionHeader, Apphud.platform.sessionId)
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

        await ApphudInternal.shared.logout()

        XCTAssertNotEqual(session.sessionId, id)
    }
    #endif
}
