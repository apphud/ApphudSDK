//
//  ApphudInternal.swift
//  subscriptionstest
//
//  Created by ren6 on 01/07/2019.
//  Copyright © 2019 apphud. All rights reserved.
//

import Foundation
import StoreKit
#if os(iOS)
import SystemConfiguration
#endif

internal typealias HasPurchasesChanges = (hasSubscriptionChanges: Bool, hasNonRenewingChanges: Bool)
internal typealias ApphudPaywallsCallback = ([ApphudPaywall], Error?) -> Void
internal typealias ApphudRetryLog = (count: Int, errorCode: Int)

internal let ApphudUserCacheKey = "ApphudUser"
internal let ApphudPlacementsCacheKey = "ApphudPlacements"
internal let ApphudPaywallsCacheKey = "ApphudPaywalls"
internal let ApphudProductGroupsCacheKey = "ApphudProductGroups"
internal let ApphudUserPropertiesCacheKey = "ApphudUserPropertiesCache"
internal let ApphudFlagString = "ApphudReinstallFlag"

internal let ApphudInitializeGuardText = "Attempted to use Apphud SDK method earlier than initialization. You should initialize SDK first."

internal let submittedAFDataKey = "submittedAFDataKey"
internal let submittedAdjustDataKey = "submittedAdjustDataKey"

final class ApphudInternal: NSObject {

    internal static let shared = ApphudInternal()
    internal var httpClient: ApphudHttpClient?
    internal var delegate: ApphudDelegate?
    internal weak var uiDelegate: ApphudUIDelegate?

    // MARK: - Private properties
    @MainActor private var userRegisteredCallbacks = [(block: ApphudVoidCallback, allowFailure: Bool)]()
    private var addedObservers = false
    private var allowIdentifyUser = true

    // MARK: - Receipt and products properties

    @MainActor internal var storeKitProductsFetchedCallbacks = [ApphudErrorCallback]()
    internal var customRegistrationAttemptsCount: Int? = nil
    internal var submitReceiptRetries: ApphudRetryLog = (0, 0)
    @MainActor internal var submitReceiptCallbacks = [ApphudNSErrorCallback?]()
    internal var restorePurchasesCallback: (([ApphudSubscription]?, [ApphudNonRenewingPurchase]?, Error?) -> Void)?
    internal var submittingTransaction: String?
    @MainActor internal var lastUploadedTransactions: [UInt64] {
        get {
            UserDefaults.standard.array(forKey: "ApphudLastUploadedTransactions") as? [UInt64] ?? [UInt64]()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ApphudLastUploadedTransactions")
        }
    }

    // MARK: - Paywalls Events
    internal var lastUploadedPaywallEvent = [String: AnyHashable]()
    internal var lastUploadedPaywallEventDate: Date?
    internal var observerModePurchaseIdentifiers: (paywall: String, placement: String?)?

    // MARK: - User registering properties
    internal var currentDeviceID: String = ""
    internal var currentUserID: String = ""
    internal var storefrontCurrency: ApphudCurrency?

    internal var isPremium: Bool = false
    internal var hasActiveSubscription: Bool = false
    
    @MainActor internal var currentUser: ApphudUser? {
        didSet {
            self.updatePremiumStatus(user: currentUser)
        }
    }
    @MainActor internal var paywalls = [ApphudPaywall]()
    @MainActor internal var placements = [ApphudPlacement]()
    @MainActor internal var permissionGroups: [ApphudGroup]?

    internal var reinstallTracked: Bool = false
    internal var delayedInitilizationParams: (apiKey: String, userID: String?, device: String?, observerMode: Bool)?
    internal var setNeedsToUpdateUser: Bool = false {
        didSet {
            DispatchQueue.main.async {
                if self.setNeedsToUpdateUser {
                    self.perform(#selector(self.updateCurrentUser), with: nil, afterDelay: 3.0)
                } else {
                    NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.updateCurrentUser), object: nil)
                }
            }
        }
    }
    internal var setNeedsToUpdateUserProperties: Bool = false {
        didSet {
            DispatchQueue.main.async {
                if self.setNeedsToUpdateUserProperties {
                    NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.updateUserProperties), object: nil)
                    self.perform(#selector(self.updateUserProperties), with: nil, afterDelay: 2.0)
                } else {
                    NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.updateUserProperties), object: nil)
                }
            }
        }
    }
    internal var lastCheckDate = Date()
    internal var userRegisterRetries: ApphudRetryLog = (0, 0)
    internal let maxNumberOfUserRegisterRetries: Int = APPHUD_INFINITE_RETRIES
    internal var paywallEventsRetriesCount: Int = 0
    internal let maxNumberOfPaywallEventsRetries: Int = 5
    internal var productsFetchRetries: ApphudRetryLog = (0, 0)
    internal let maxNumberOfProductsFetchRetries: Int = 25
    internal var didPreparePaywalls: Bool = false
    internal var deferPlacements: Bool = false
    internal var initDate = Date()
    internal var paywallsLoadTime: TimeInterval = 0
    internal var isRegisteringUser = false {
        didSet {
            if isRegisteringUser {
                apphudPerformOnMainThread {
                    NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.registerUser), object: nil)
                }
            }
        }
    }

    // MARK: - Advertising Identifier

    internal var deviceIdentifiers: (String?, String?) {
        didSet {
            if deviceIdentifiers.0 != nil || deviceIdentifiers.1 != nil {
                let delimiter = "-"
                let separator = ","
                var cachedIDFA: String? = nil
                var cachedIDFV: String? = nil
                if let cachedDeviceIds = submittedDeviceIdentifiers?.components(separatedBy: separator) {
                    cachedIDFA = cachedDeviceIds.first
                    cachedIDFV = cachedDeviceIds.last
                    if cachedIDFA == delimiter {
                        cachedIDFA = nil
                    }
                    if cachedIDFV == delimiter {
                        cachedIDFV = nil
                    }
                }
                
                if deviceIdentifiers.0 == cachedIDFA && deviceIdentifiers.1 == cachedIDFV {
                    apphudLog("Device Identifiers not changed, skipping. \(String(describing: cachedIDFA)), \(String(describing: cachedIDFV))")
                } else {
                    apphudLog("Received Device Identifiers (\(deviceIdentifiers.0 ?? ""), \(deviceIdentifiers.1 ?? "") will submit soon.")
                    self.setNeedsToUpdateUser = true
                    let idfaToCache = deviceIdentifiers.0 ?? delimiter
                    let idfvToCache = deviceIdentifiers.1 ?? delimiter
                    submittedDeviceIdentifiers = idfaToCache + separator + idfvToCache
                }
                
            }
        }
    }

    // MARK: - Attribution properties
    internal var requiresReceiptSubmission: Bool {
        get {
            UserDefaults.standard.bool(forKey: "requiresReceiptSubmissionKey")
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "requiresReceiptSubmissionKey")
        }
    }
    internal let didSubmitAppsFlyerAttributionKey = "didSubmitAppsFlyerAttributionKey"
    internal let didSubmitAdjustAttributionKey = "didSubmitAdjustAttributionKey"
    internal let didSubmitProductPricesKey = "didSubmitProductPricesKey"
    internal let submittedFirebaseIdKey = "submittedFirebaseIdKey"
    internal let submittedFacebookAnonIdKey = "submittedFacebookAnonIdKey"
    internal var didSubmitAppleAdsAttributionKey = "didSubmitAppleAdsAttributionKey"
    internal let submittedPushTokenKey = "submittedPushTokenKey"
    internal let submittedDeviceIdentifiersKey = "submittedDeviceIdentifiersKey"
    internal let swizzlePaymentDisabledKey = "swizzlePaymentDisabledKey"
    internal var isSendingAppsFlyer = false
    internal var isSendingAdjust = false
    internal var isFreshInstall = true
    internal var isRedownload = false
    internal var didHandleBecomeActive = false
    internal var respondedStoreKitProducts = false

    internal var purchasingProduct: ApphudProduct?
    internal var pendingTransactionID: String?
    internal var fallbackMode = false
    internal var registrationStartedAt: Date?
    @MainActor internal var currencyTaskFinished = false
    internal var initialRequestID = UUID().uuidString
    
    internal var isInitialized: Bool {
        httpClient != nil
    }

    internal var didSubmitAppsFlyerAttribution: Bool {
        get {
            UserDefaults.standard.bool(forKey: didSubmitAppsFlyerAttributionKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: didSubmitAppsFlyerAttributionKey)
        }
    }
    internal var didSubmitAdjustAttribution: Bool {
        get {
            UserDefaults.standard.bool(forKey: didSubmitAdjustAttributionKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: didSubmitAdjustAttributionKey)
        }
    }
    internal var didSubmitProductPrices: Bool {
        get {
            UserDefaults.standard.bool(forKey: didSubmitProductPricesKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: didSubmitProductPricesKey)
        }
    }
    internal var didSubmitAppleAdsAttribution: Bool {
        get {
            UserDefaults.standard.bool(forKey: didSubmitAppleAdsAttributionKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: didSubmitAppleAdsAttributionKey)
        }
    }
    internal var submittedFacebookAnonId: String? {
        get {
            UserDefaults.standard.string(forKey: submittedFacebookAnonIdKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: submittedFacebookAnonIdKey)
        }
    }
    internal var submittedFirebaseId: String? {
        get {
            UserDefaults.standard.string(forKey: submittedFirebaseIdKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: submittedFirebaseIdKey)
        }
    }
    internal var submittedPushToken: String? {
        get {
            UserDefaults.standard.string(forKey: submittedPushTokenKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: submittedPushTokenKey)
        }
    }
    internal var submittedDeviceIdentifiers: String? {
        get {
            UserDefaults.standard.string(forKey: submittedDeviceIdentifiersKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: submittedDeviceIdentifiersKey)
        }
    }

    // MARK: - Initialization

    @MainActor
    internal func initialize(apiKey: String, inputUserID: String?, inputDeviceID: String? = nil, observerMode: Bool) {

        #if os(iOS) || os(tvOS)
        if !ApphudKeychain.canUseKeychain && !ApphudKeychain.hasLocalStorageData && UIApplication.shared.applicationState != .active {
            setupObservers()
            apphudLog("Unable to initialize right now, will wait until app becomes active", forceDisplay: true)
            self.delayedInitilizationParams = (apiKey, inputUserID, inputDeviceID, observerMode)
            return
        }
        #endif

        if httpClient == nil {
            ApphudStoreKitWrapper.shared.setupObserver()
            httpClient = ApphudHttpClient.shared
        }

        httpClient!.apiKey = apiKey
        apphudLog("Started Apphud SDK (\(ApphudHttpClient.shared.sdkVersion))", forceDisplay: true)

        guard allowIdentifyUser == true else {
            apphudLog("Abort initializing, because Apphud SDK already initialized. You can only call `Apphud.start()` once per app lifecycle. Or if `Apphud.logout()` was called previously.", forceDisplay: true)
            return
        }
        allowIdentifyUser = false

        identify(inputUserID: inputUserID, inputDeviceID: inputDeviceID, observerMode: observerMode)
    }

    @MainActor
    internal func identify(inputUserID: String?, inputDeviceID: String? = nil, observerMode: Bool) {
        ApphudUtils.shared.storeKitObserverMode = observerMode

        var deviceID = ApphudKeychain.loadDeviceID()
        let userIDFromKeychain = ApphudKeychain.loadUserID()

        isFreshInstall = deviceID == nil
        isRedownload = deviceID != nil && UserDefaults.standard.string(forKey: ApphudFlagString) == nil
        UserDefaults.standard.set(ApphudFlagString, forKey: ApphudFlagString)

        if inputDeviceID?.count ?? 0 > 0 {
            deviceID = inputDeviceID
        }

        let generatedUUID: String = ApphudKeychain.generateUUID()

        if deviceID == nil {
            deviceID = generatedUUID
            ApphudKeychain.saveDeviceID(deviceID: deviceID!)
        }

        self.currentDeviceID = deviceID!

        setupObservers()

        let cachedUser = ApphudUser.fromCacheV2()

        if inputUserID?.count ?? 0 > 0 {
            self.currentUserID = inputUserID!
        } else if let existingUserID = cachedUser?.userId {
            self.currentUserID = existingUserID
        } else if userIDFromKeychain != nil {
            self.currentUserID = userIDFromKeychain!
        } else {
            self.currentUserID = generatedUUID
        }

        self.currentUser = cachedUser
        self.initDate = Date()
        
        Task(priority: .userInitiated) {

            var isIdenticalUserIds = true
            if self.currentUserID != userIDFromKeychain {
                isIdenticalUserIds = false
                Task { @MainActor in
                    ApphudKeychain.saveUserID(userID: self.currentUserID)
                }
            }

            let cachedPwls = await cachedPaywalls()
            let cachedPlacements = await cachedPlacements()
            let cachedGroups = await cachedGroups()

            await MainActor.run {
                self.paywalls = cachedPwls.objects ?? []
                self.placements = cachedPlacements.objects ?? []
                // permissionGroups array can be nil
                self.permissionGroups = cachedGroups.objects
            }

            await fetchCurrencyIfNeeded()

            self.continueToRegisteringUser(skipRegistration: self.skipRegistration(isIdenticalUserIds: isIdenticalUserIds, hasCashedUser: self.currentUser != nil, hasCachedPaywalls: !cachedPwls.expired))
        }
    }

    @MainActor private func skipRegistration(isIdenticalUserIds: Bool, hasCashedUser: Bool, hasCachedPaywalls: Bool) -> Bool {
        return isIdenticalUserIds && hasCashedUser && hasCachedPaywalls && !isUserCacheExpired() && !isUserPaid()
    }

    @MainActor private func isUserPaid() -> Bool {
       return self.currentUser?.subscriptions.count ?? 0 > 0 || self.currentUser?.purchases.count ?? 0 > 0
    }

    internal var cacheTimeout: TimeInterval = apphudIsSandbox() ? 60 : 90000
    internal func setCacheTimeout(_ value: TimeInterval) {
        if (value >= 0 && value < 86_400*2) {
            self.cacheTimeout = value
        }
    }

    private func isUserCacheExpired() -> Bool {
        if let lastUserUpdatedDate = ApphudLoggerService.lastUserUpdatedAt, Date().timeIntervalSince(lastUserUpdatedDate) < cacheTimeout {
            return false
        } else {
            return true
        }
    }

    internal func continueToRegisteringUser(skipRegistration: Bool = false, needToUpdateProductGroups: Bool = true) {
        guard !isRegisteringUser else {return}
        guard self.httpClient != nil else {return}
        isRegisteringUser = true

        registerUser(skipRegistration: skipRegistration)
    }

    @objc private func registerUser(skipRegistration: Bool = false) {
        Task.detached(priority: .userInitiated) {
            let response = await self.createOrGetUser(initialCall: true, skipRegistration: skipRegistration)

            let success = response.0
            let errorCode = response.1

            self.isRegisteringUser = false

            if success {
                self.userRegisterRetries = (0, 0)
                apphudLog("User successfully registered with id: \(self.currentUserID)", forceDisplay: true)
                Task { @MainActor in
                    self.performAllUserRegisteredBlocks()
                    self.checkForUnreadNotifications()
                    self.migrateiOS14PurchasesIfNeeded()
                    self.perform(#selector(self.forceSendAttributionDataIfNeeded), with: nil, afterDelay: 10.0)
                }
            } else {
                Task { @MainActor in
                    self.scheduleUserRegistering(errorCode: errorCode)
                }
            }

            if await self.isApplicationActive && !self.didHandleBecomeActive {
                Task { @MainActor in
                    self.handleDidBecomeActive()
                }
            }
        }
    }

    private func willRetryUserRegistration() -> Bool {
        userRegisterRetries.count < maxNumberOfUserRegisterRetries
    }

    @MainActor
    private func scheduleUserRegistering(errorCode: Int) {
        guard httpClient != nil, httpClient!.canRetry else {
            return
        }
        guard willRetryUserRegistration() else {
            apphudLog("Reached max number of user register retries \(userRegisterRetries.count). Exiting..", forceDisplay: true)
            return
        }

        let retryImmediately = [NSURLErrorRedirectToNonExistentLocation, NSURLErrorUnknown, NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost]
        let noInternetError = [NSURLErrorNotConnectedToInternet, NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost]

        var delay: TimeInterval = 0

        let serverIsUnreachable = [NSURLErrorCannotConnectToHost, NSURLErrorTimedOut, 500, 502, 503].contains(errorCode)
        
        userRegisterRetries.count += 1
        userRegisterRetries.errorCode = errorCode
        
        let maxAttempts = min(self.customRegistrationAttemptsCount ?? APPHUD_DEFAULT_RETRIES, APPHUD_DEFAULT_RETRIES)
        
        if serverIsUnreachable && (userRegisterRetries.count >= maxAttempts || Date().timeIntervalSince(initDate) > APPHUD_MAX_INITIAL_LOAD_TIME) {
            executeFallback(callback: nil)
        }
        
        if (userRegisterRetries.count >= maxAttempts && currentUser == nil || currentUser != nil) {
            performAllUserFailedBlocks()
        }
        
        if retryImmediately.contains(errorCode) {
            delay = 0.5
        } else if noInternetError.contains(errorCode) {
            userRegisterRetries.errorCode = APPHUD_ERROR_NO_INTERNET
            delay = 1.0
        } else {
            delay = 0.5 * Double(userRegisterRetries.count)
        }

        if fallbackMode {
            delay *= 2.0
        }
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(registerUser), object: nil)
        perform(#selector(registerUser), with: nil, afterDelay: delay)
        apphudLog("Scheduled user register retry in \(delay) seconds.", forceDisplay: true)
    }

    // MARK: - Other
    @MainActor
    var applicationDidBecomeActiveNotification: Notification.Name {
        #if os(iOS) || os(tvOS)
            UIApplication.didBecomeActiveNotification
        #elseif os(macOS)
            NSApplication.didBecomeActiveNotification
        #elseif os(watchOS)
            Notification.Name.NSExtensionHostDidBecomeActive
        #elseif os(visionOS)
            Notification.Name.NSExtensionHostDidBecomeActive
        #endif
    }

    @MainActor
    var isApplicationActive: Bool {
        #if os(iOS) || os(tvOS)
            UIApplication.shared.applicationState == .active
        #else
            true
        #endif
    }

    @MainActor
    private func setupObservers() {
        if !addedObservers {
            NotificationCenter.default.addObserver(self, selector: #selector(handleDidBecomeActive), name: applicationDidBecomeActiveNotification, object: nil)
            addedObservers = true
        }
    }

    @MainActor
    private func checkPendingRules() {
        #if os(iOS)
        performWhenUserRegistered {
            ApphudRulesManager.shared.handlePendingAPSInfo()
        }
        #endif
    }

    @MainActor
    @objc private func handleDidBecomeActive() {

        didHandleBecomeActive = true

        apphudLog("App did become active")

        if let delayedParams = delayedInitilizationParams {
            initialize(apiKey: delayedParams.apiKey, inputUserID: delayedParams.userID, inputDeviceID: delayedParams.device, observerMode: delayedParams.observerMode)
            delayedInitilizationParams = nil
        }

        checkPendingRules()
        setNeedToCheckTransactions()

        let minCheckInterval: Double = 60
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.currentUser == nil && !self.willRetryUserRegistration() {
                self.continueToRegisteringUser()
            } else if Date().timeIntervalSince(self.lastCheckDate) > minCheckInterval {
                self.lastCheckDate = Date()
                self.checkForUnreadNotifications()
                if self.isUserCacheExpired() && self.isUserPaid() {
                    self.setNeedsToUpdateUser = true
                }
            }
        }
    }

    // MARK: - Perform Blocks

    /// Returns false if current user is not yet registered, block is added to array and will be performed later.
    internal func performWhenUserRegistered(allowFailure: Bool = false, callback : @escaping ApphudVoidMainCallback) {
        // detach to call in the next run loop
        Task.detached { @MainActor in
            if self.currentUser != nil {
                callback()
            } else {
                if self.userRegisterRetries.count >= self.maxNumberOfUserRegisterRetries {
                    self.continueToRegisteringUser()
                }
                                
                self.userRegisteredCallbacks.append((callback, allowFailure))
            }
        }
    }

    internal func performAllUserRegisteredBlocks() {
        // detach to call in the next run loop
        Task.detached { @MainActor in
            while !self.userRegisteredCallbacks.isEmpty {
                self.userRegisteredCallbacks.removeFirst().block()
            }
        }
    }
    
    internal func performAllUserFailedBlocks() {
        // detach to call in the next run loop
        Task.detached { @MainActor in
            for tuple in self.userRegisteredCallbacks {
                if (tuple.allowFailure) {
                    tuple.block()
                }
            }
            self.userRegisteredCallbacks.removeAll(where: { $0.allowFailure == true })
        }
    }


    // MARK: - Push Notifications API

    internal func submitPushNotificationsToken(token: Data, callback: ApphudBoolCallback?) {
        let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
        submitPushNotificationsTokenString(tokenString, callback: callback)
    }

    internal func submitPushNotificationsTokenString(_ tokenString: String, callback: ApphudBoolCallback?) {
        performWhenUserRegistered {

            guard tokenString != "", self.submittedPushToken != tokenString else {
                apphudLog("Already submitted the same push token, exiting")
                callback?(true)
                return
            }
            let params: [String: String] = ["device_id": self.currentDeviceID, "push_token": tokenString]
            self.httpClient?.startRequest(path: .push, params: params, method: .put) { (result, _, _, _, _, _, _) in
                if result {
                    self.submittedPushToken = tokenString
                }
                callback?(result)
            }
        }
    }

    // MARK: - V2 API

    internal func trackDurationLogs(params: [[String: AnyHashable]], callback: @escaping () -> Void) {
        performWhenUserRegistered {
            var final_params: [String: AnyHashable] = ["device_id": self.currentDeviceID,
                                                       "user_id": self.currentUserID,
                                                       "bundle_id": Bundle.main.bundleIdentifier,
                                                       "data": params]

            #if os(iOS)
            final_params["connection_type"] = self.currentReachabilityStatus.rawValue
            #endif

            self.httpClient?.startRequest(path: .logs, apiVersion: .APIV3, params: final_params, method: .post) { (_, _, _, _, _, _, _) in
                callback()
            }
        }
    }

    internal func trackEvent(params: [String: AnyHashable], callback: @escaping () -> Void) {
        performWhenUserRegistered {
            let final_params: [String: AnyHashable] = ["device_id": self.currentDeviceID].merging(params, uniquingKeysWith: {(current, _) in current})
            self.httpClient?.startRequest(path: .events, apiVersion: .APIV2, params: final_params, method: .post) { (_, _, _, _, _, _, _) in
                callback()
            }
        }
    }

    @objc internal func trackPaywallEvent(params: [String: AnyHashable]) {
        if self.lastUploadedPaywallEvent == params && Date().timeIntervalSince(lastUploadedPaywallEventDate ?? Date()) <= 2 {
            apphudLog("Skip paywall event bacause the same event just been uploaded")
            return
        } else {
            self.lastUploadedPaywallEvent = params
            self.lastUploadedPaywallEventDate = Date()
        }

        submitPaywallEvent(params: params) { (_, _, _, _, _, _, _) in }
    }

    internal func submitPaywallEvent(params: [String: AnyHashable], callback: @escaping ApphudHTTPResponseCallback) {
        performWhenUserRegistered {
            let environment = Apphud.isSandbox() ? ApphudEnvironment.sandbox.rawValue : ApphudEnvironment.production.rawValue
            let final_params: [String: AnyHashable] = ["device_id": self.currentDeviceID,
                                                       "user_id": self.currentUserID,
                                                       "timestamp": Date().currentTimestamp,
                                                       "environment": environment].merging(params, uniquingKeysWith: {(current, _) in current})

            self.httpClient?.startRequest(path: .events, apiVersion: .APIV1, params: final_params, method: .post, retry: true, callback: callback)
        }
    }

    /// Not used yet
    internal func getRule(ruleID: String, callback: @escaping (ApphudRule?) -> Void) {

        performWhenUserRegistered {
            let params = ["device_id": self.currentDeviceID] as [String: String]

            self.httpClient?.startRequest(path: .rule(ruleID), apiVersion: .APIV2, params: params, method: .get) { (result, response, _, _, _, _, _) in
                if result, let dataDict = response?["data"] as? [String: Any],
                    let ruleDict = dataDict["results"] as? [String: Any] {
                    callback(ApphudRule(dictionary: ruleDict))
                } else {
                    callback(nil)
                }
            }
        }
    }

    internal func checkForUnreadNotifications() {
        #if os(iOS)
        performWhenUserRegistered {
            let params = ["device_id": self.currentDeviceID] as [String: String]
            self.httpClient?.startRequest(path: .notifications, apiVersion: .APIV2, params: params, method: .get, callback: { (result, response, _, _, _, _, _) in

                if result, let dataDict = response?["data"] as? [String: Any], let notifArray = dataDict["results"] as? [[String: Any]], let notifDict = notifArray.first, var ruleDict = notifDict["rule"] as? [String: Any] {
                    let properties = notifDict["properties"] as? [String: Any]
                    ruleDict = ruleDict.merging(properties ?? [:], uniquingKeysWith: {_, new in new})
                    let rule = ApphudRule(dictionary: ruleDict)
                    Task { @MainActor in
                        ApphudRulesManager.shared.handleRule(rule: rule)
                    }
                }
            })
        }
        #endif
    }

    internal func readAllNotifications(for ruleID: String) {
        performWhenUserRegistered {
            let params = ["device_id": self.currentDeviceID, "rule_id": ruleID] as [String: String]
            self.httpClient?.startRequest(path: .readNotifications, apiVersion: .APIV2, params: params, method: .post, callback: { (_, _, _, _, _, _, _) in
            })
        }
    }

    internal func getActiveRuleScreens(_ callback: @escaping ([String]) -> Void) {
        performWhenUserRegistered {
            self.httpClient?.startRequest(path: .screens, apiVersion: .APIV2, params: nil, method: .get) { result, response, _, _, _, _, _ in
                if result, let dataDict = response?["data"] as? [String: Any], let screensIdsArray = dataDict["results"] as? [String] {
                    callback(screensIdsArray)
                } else {
                    callback([])
                }
            }
        }
    }

    internal func logout() async {

        await ApphudDataActor.shared.clear()
        await ApphudKeychain.resetValues()

        await ApphudUser.clearCache()
        currentUserID = ""
        currentDeviceID = ""

        /** Permissions groups never change, no need to clear from cache.
        apphudDataClearCache(key: ApphudProductGroupsCacheKey)
        permissionGroups = nil
        */

        await ApphudDataActor.shared.apphudDataClearCache(key: ApphudPaywallsCacheKey)
        await ApphudDataActor.shared.apphudDataClearCache(key: ApphudPlacementsCacheKey)

        await MainActor.run {
            currencyTaskFinished = false
            paywalls.removeAll()
            placements.removeAll()
            currentUser = nil
            isPremium = false
            hasActiveSubscription = false
            userRegisteredCallbacks.removeAll()
            storeKitProductsFetchedCallbacks.removeAll()
            submitReceiptCallbacks.removeAll()
            lastUploadedTransactions = []
        }

        didPreparePaywalls = false
        
        submitReceiptRetries = (0, 0)
        restorePurchasesCallback = nil
        submittingTransaction = nil
        lastUploadedPaywallEvent.removeAll()
        lastUploadedPaywallEventDate = nil
        reinstallTracked = false
        delayedInitilizationParams = nil
        setNeedsToUpdateUser = false
        setNeedsToUpdateUserProperties = false
        await ApphudDataActor.shared.setPendingUserProperties([])
        userRegisterRetries = (0, 0)
        paywallEventsRetriesCount = 0
        productsFetchRetries = (0, 0)
        isRegisteringUser = false
        respondedStoreKitProducts = false
        fallbackMode = false
        registrationStartedAt = nil
        didSubmitAppsFlyerAttribution = false
        didSubmitAdjustAttribution = false
        didSubmitProductPrices = false
        didSubmitAppleAdsAttribution = false
        submittedFirebaseId = nil
        submittedPushToken = nil

        observerModePurchaseIdentifiers = nil

        allowIdentifyUser = true
        apphudLog("User logged out. Apphud SDK is uninitialized.", logLevel: .all)
    }
}

extension Date {
    /// Returns current Timestamp
    var currentTimestamp: Int64 {
      Int64(self.timeIntervalSince1970 * 1000)
    }
}

#if os(iOS)
extension ApphudInternal {
    enum ApphudConnectionType: String {
        case none
        case cellular
        case wifi
    }

    var currentReachabilityStatus: ApphudConnectionType {
        var zeroAddress = sockaddr_in()
        zeroAddress.sin_len = UInt8(MemoryLayout<sockaddr_in>.size)
        zeroAddress.sin_family = sa_family_t(AF_INET)
        guard let defaultRouteReachability = withUnsafePointer(to: &zeroAddress, {
            $0.withMemoryRebound(to: sockaddr.self, capacity: 1) {
                SCNetworkReachabilityCreateWithAddress(nil, $0)
            }
        }) else {
            return .none
        }

        var flags: SCNetworkReachabilityFlags = []
        if !SCNetworkReachabilityGetFlags(defaultRouteReachability, &flags) {
            return .none
        }

        if flags.contains(.reachable) == false {
            return .none
        } else if flags.contains(.isWWAN) == true {
            return .cellular
        } else if flags.contains(.connectionRequired) == false {
            return .wifi
        } else if (flags.contains(.connectionOnDemand) == true || flags.contains(.connectionOnTraffic) == true) && flags.contains(.interventionRequired) == false {
            return .wifi
        } else {
            return .none
        }
    }
}
#endif
