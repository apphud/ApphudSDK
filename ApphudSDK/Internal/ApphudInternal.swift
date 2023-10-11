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
internal typealias ApphudPaywallsCallback = ([ApphudPaywall]) -> Void
internal typealias ApphudRetryLog = (count: Int, errorCode: Int)

internal let ApphudFlagString = "ApphudReinstallFlag"

internal let ApphudInitializeGuardText = "Attempted to use Apphud SDK method earlier than initialization. You should initialize SDK first."

final class ApphudInternal: NSObject {

    internal static let shared = ApphudInternal()
    internal var httpClient: ApphudHttpClient?
    internal var delegate: ApphudDelegate?
    internal weak var uiDelegate: ApphudUIDelegate?

    // MARK: - Private properties
    private var userRegisteredCallbacks = [ApphudVoidCallback]()
    private var addedObservers = false
    private var allowIdentifyUser = true

    // MARK: - Receipt and products properties

    internal var customPaywallsLoadedCallbacks = [ApphudPaywallsCallback]()
    internal var productGroupsFetchedCallbacks = [ApphudVoidCallback]()
    internal var storeKitProductsFetchedCallbacks = [ApphudVoidCallback]()
    internal var customProductsFetchedBlocks = [ApphudStoreKitProductsCallback]()
    internal var productGroups = [ApphudGroup]()
    internal var paywalls = [ApphudPaywall]()

    internal var submitReceiptRetries: ApphudRetryLog = (0, 0)
    internal var submitReceiptCallbacks = [ApphudErrorCallback?]()
    internal var restorePurchasesCallback: (([ApphudSubscription]?, [ApphudNonRenewingPurchase]?, Error?) -> Void)?
    internal var isSubmittingReceipt: Bool = false
    internal var lastUploadedTransactions: [UInt64] {
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
    internal var observerModePurchasePaywallIdentifier: String?

    // MARK: - User registering properties
    internal var currentUser: ApphudUser?
    internal var currentDeviceID: String = ""
    internal var currentUserID: String = ""
    internal var reinstallTracked: Bool = false
    internal var delayedInitilizationParams: (apiKey: String, userID: String?, device: String?, observerMode: Bool)?
    internal var setNeedsToUpdateUser: Bool = false {
        didSet {
            if setNeedsToUpdateUser {
                self.perform(#selector(updateCurrentUser), with: nil, afterDelay: 2.0)
            } else {
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateCurrentUser), object: nil)
            }
        }
    }
    internal var setNeedsToUpdateUserProperties: Bool = false {
        didSet {
            if setNeedsToUpdateUserProperties {
                self.perform(#selector(updateUserProperties), with: nil, afterDelay: 1.0)
            } else {
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(updateUserProperties), object: nil)
            }
        }
    }
    internal var pendingUserProperties = [ApphudUserProperty]()
    internal var lastCheckDate = Date()
    internal var userRegisterRetries: ApphudRetryLog = (0, 0)
    internal let maxNumberOfUserRegisterRetries: Int = 25
    internal var paywallEventsRetriesCount: Int = 0
    internal let maxNumberOfPaywallEventsRetries: Int = 25
    internal var productsFetchRetries: ApphudRetryLog = (0, 0)
    internal let maxNumberOfProductsFetchRetries: Int = 25
    internal var didPreparePaywalls: Bool = false
    internal var initDate = Date()
    internal var paywallsLoadTime: TimeInterval = 0
    internal var isRegisteringUser = false {
        didSet {
            if isRegisteringUser {
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(registerUser), object: nil)
            }
        }
    }

    // MARK: - Advertising Identifier

    internal var advertisingIdentifier: String? {
        didSet {
            if advertisingIdentifier != nil {
                apphudLog("Received IDFA (\(advertisingIdentifier ?? ""), will submit soon.")
                apphudPerformOnMainThread {
                    self.setNeedsToUpdateUser = true
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
    internal let submittedAFDataKey = "submittedAFDataKey"
    internal let submittedAdjustDataKey = "submittedAdjustDataKey"
    internal var didSubmitAppleAdsAttributionKey = "didSubmitAppleAdsAttributionKey"
    internal let submittedPushTokenKey = "submittedPushTokenKey"
    internal let swizzlePaymentDisabledKey = "swizzlePaymentDisabledKey"
    internal var isSendingAppsFlyer = false
    internal var isSendingAdjust = false
    internal var isFreshInstall = true
    internal var isRedownload = false
    internal var didHandleBecomeActive = false
    internal var respondedStoreKitProducts = false

    internal var fallbackMode = false
    internal var registrationStartedAt: Date?

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
    internal var submittedAFData: [AnyHashable: Any]? {
        get {
            let cache = apphudDataFromCache(key: submittedAFDataKey, cacheTimeout: 86_400*7)
            if let data = cache.objectsData, !cache.expired,
                let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [AnyHashable: Any] {
                return object
            } else {
                return nil
            }
        }
        set {
            if newValue != nil, let data = try? JSONSerialization.data(withJSONObject: newValue!, options: .prettyPrinted) {
                apphudDataToCache(data: data, key: submittedAFDataKey)
            }
        }
    }
    internal var submittedAdjustData: [AnyHashable: Any]? {
        get {
            let cache = apphudDataFromCache(key: submittedAdjustDataKey, cacheTimeout: 86_400*7)
            if let data = cache.objectsData, !cache.expired,
                let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [AnyHashable: Any] {
                return object
            } else {
                return nil
            }
        }
        set {
            if newValue != nil, let data = try? JSONSerialization.data(withJSONObject: newValue!, options: .prettyPrinted) {
                apphudDataToCache(data: data, key: submittedAdjustDataKey)
            }
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

    // MARK: - Initialization

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
            httpClient!.apiKey = apiKey
            apphudLog("Started Apphud SDK (\(ApphudHttpClient.shared.sdkVersion))", forceDisplay: true)
        }

        guard allowIdentifyUser == true else {
            apphudLog("Abort initializing, because Apphud SDK already initialized. You can only call `Apphud.start()` once per app lifecycle. Or if `Apphud.logout()` was called previously.", forceDisplay: true)
            return
        }
        allowIdentifyUser = false

        identify(inputUserID: inputUserID, inputDeviceID: inputDeviceID, observerMode: observerMode)
    }

    internal func identify(inputUserID: String?, inputDeviceID: String? = nil, observerMode: Bool) {

        ApphudUtils.shared.storeKitObserverMode = observerMode

        var deviceID = ApphudKeychain.loadDeviceID()

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

        self.currentUser = ApphudUser.fromCacheV2(isFreshInstall)
        let userIDFromKeychain = ApphudKeychain.loadUserID()

        if inputUserID?.count ?? 0 > 0 {
            self.currentUserID = inputUserID!
        } else if let existingUserID = self.currentUser?.userId {
            self.currentUserID = existingUserID
        } else if userIDFromKeychain != nil {
            self.currentUserID = userIDFromKeychain!
        } else {
            self.currentUserID = generatedUUID
        }

        var isIdenticalUserIds = true
        if self.currentUserID != userIDFromKeychain {
            isIdenticalUserIds = false
            ApphudKeychain.saveUserID(userID: self.currentUserID)
        }

        let cachedGroups = cachedGroups()
        self.productGroups = cachedGroups.objects ?? []

        let cachedPwls = cachedPaywalls()
        self.paywalls = cachedPwls.objects ?? []

        setupObservers()

        DispatchQueue.main.async {
            self.continueToRegisteringUser(skipRegistration: self.skipRegistration(isIdenticalUserIds: isIdenticalUserIds, hasCashedUser: self.currentUser != nil, hasCachedPaywalls: !cachedPwls.expired), needToUpdateProductGroups: cachedGroups.expired)
        }
    }

    private func skipRegistration(isIdenticalUserIds: Bool, hasCashedUser: Bool, hasCachedPaywalls: Bool) -> Bool {
        return isIdenticalUserIds && hasCashedUser && hasCachedPaywalls && !isUserCacheExpired() && !isUserPaid()
    }

    private func isUserPaid() -> Bool {
       return self.currentUser?.subscriptions.count ?? 0 > 0 || self.currentUser?.purchases.count ?? 0 > 0
    }

    internal var cacheTimeout: TimeInterval {
        apphudIsSandbox() ? 60 : 90000
    }

    private func isUserCacheExpired() -> Bool {
        if let lastUserUpdatedDate = ApphudLoggerService.lastUserUpdatedAt, Date().timeIntervalSince(lastUserUpdatedDate) < cacheTimeout {
            return false
        } else {
            return true
        }
    }

    internal func logout() {
        ApphudUser.clearCache()
        ApphudKeychain.resetValues()
        ApphudPaywall.clearCache()
        allowIdentifyUser = true
        apphudLog("User logged out. Apphud SDK is uninitialized.", logLevel: .all)
    }

    internal func continueToRegisteringUser(skipRegistration: Bool = false, needToUpdateProductGroups: Bool = true) {
        guard !isRegisteringUser else {return}
        guard self.httpClient != nil else {return}
        isRegisteringUser = true

        // in observer mode need to fetch products too, for Updating currency and Rules
        continueToFetchProducts(needToUpdateProductGroups: needToUpdateProductGroups, fallbackProducts: nil)

        registerUser(skipRegistration: skipRegistration)
    }

    @objc private func registerUser(skipRegistration: Bool = false) {
        createOrGetUser(shouldUpdateUserID: true, skipRegistration: skipRegistration) { success, errorCode in

            self.isRegisteringUser = false

            if success {
                self.userRegisterRetries = (0, 0)
                apphudLog("User successfully registered with id: \(self.currentUserID)", forceDisplay: true)
                self.performAllUserRegisteredBlocks()
                self.checkForUnreadNotifications()
                self.perform(#selector(self.forceSendAttributionDataIfNeeded), with: nil, afterDelay: 10.0)
            } else {
                self.scheduleUserRegistering(errorCode: errorCode)
            }

            if self.isApplicationActive && !self.didHandleBecomeActive {
                self.handleDidBecomeActive()
            }
        }
    }

    private func willRetryUserRegistration() -> Bool {
        userRegisterRetries.count < maxNumberOfUserRegisterRetries
    }

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

        var delay: TimeInterval

        let serverIsUnreachable = [NSURLErrorCannotConnectToHost, NSURLErrorTimedOut, 500, 502, 503].contains(errorCode)
        if serverIsUnreachable {
            executeFallback()
        }

        if retryImmediately.contains(errorCode) {
            delay = 0.5
        } else if noInternetError.contains(errorCode) {
            delay = 2.0
        } else {
            delay = 2.0
            userRegisterRetries.count += 1
            userRegisterRetries.errorCode = errorCode
        }

        if fallbackMode {
            delay *= 3.0
        }

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(registerUser), object: nil)
        perform(#selector(registerUser), with: nil, afterDelay: delay)
        apphudLog("Scheduled user register retry in \(delay) seconds.", forceDisplay: true)
    }

    // MARK: - Other

    var applicationDidBecomeActiveNotification: Notification.Name {
        #if os(iOS) || os(tvOS)
            UIApplication.didBecomeActiveNotification
        #elseif os(macOS)
            NSApplication.didBecomeActiveNotification
        #elseif os(watchOS)
            Notification.Name.NSExtensionHostDidBecomeActive
        #endif
    }

    var isApplicationActive: Bool {
        #if os(iOS) || os(tvOS)
            UIApplication.shared.applicationState == .active
        #else
            true
        #endif
    }

    private func setupObservers() {
        if !addedObservers {
            NotificationCenter.default.addObserver(self, selector: #selector(handleDidBecomeActive), name: applicationDidBecomeActiveNotification, object: nil)
            addedObservers = true
        }
    }

    private func checkPendingRules() {
        #if os(iOS)
        performWhenUserRegistered {
            ApphudRulesManager.shared.handlePendingAPSInfo()
        }
        #endif
    }

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
    @discardableResult internal func performWhenUserRegistered(callback : @escaping ApphudVoidCallback) -> Bool {
        if currentUser != nil {
            DispatchQueue.main.async {
                callback()
            }
            return true
        } else {
            if userRegisterRetries.count >= maxNumberOfUserRegisterRetries {
                continueToRegisteringUser()
            }
            userRegisteredCallbacks.append(callback)
            return false
        }
    }

    internal func performAllUserRegisteredBlocks() {
        DispatchQueue.main.async {
            for block in self.userRegisteredCallbacks {
                block()
            }
            if self.userRegisteredCallbacks.count > 0 {
                apphudLog("All scheduled blocks performed, removing..")
                self.userRegisteredCallbacks.removeAll()
            }
        }
    }

    /// Returns false if products groups map dictionary not yet received, block is added to array and will be performed later.
    @discardableResult internal func performWhenProductGroupsFetched(callback : @escaping ApphudVoidCallback) -> Bool {
        if self.productGroups.count > 0 {
            DispatchQueue.main.async {
                callback()
            }
            return true
        } else {
            productGroupsFetchedCallbacks.append(callback)
            return false
        }
    }

    internal func performAllProductGroupsFetchedCallbacks() {
        DispatchQueue.main.async {
            for block in self.productGroupsFetchedCallbacks {
                apphudLog("Performing scheduled block..")
                block()
            }
            if self.productGroupsFetchedCallbacks.count > 0 {
                apphudLog("All scheduled blocks performed, removing..")
                self.productGroupsFetchedCallbacks.removeAll()
            }
        }
    }

    /// Returns false if products groups map dictionary not yet received, block is added to array and will be performed later.
    @discardableResult internal func performWhenStoreKitProductFetched(callback : @escaping ApphudVoidCallback) -> Bool {
        if ApphudStoreKitWrapper.shared.didFetch {
            DispatchQueue.main.async {
                callback()
            }
            return true
        } else {
            self.storeKitProductsFetchedCallbacks.append(callback)
            return false
        }
    }

    internal func performAllStoreKitProductsFetchedCallbacks() {
        DispatchQueue.main.async {
            for block in self.storeKitProductsFetchedCallbacks {
                apphudLog("Performing scheduled block..")
                block()
            }
            if self.storeKitProductsFetchedCallbacks.count > 0 {
                apphudLog("All scheduled blocks performed, removing..")
                self.storeKitProductsFetchedCallbacks.removeAll()
            }
        }
    }

    // MARK: - Push Notifications API

    internal func submitPushNotificationsToken(token: Data, callback: ApphudBoolCallback?) {
        performWhenUserRegistered {

            let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
            guard tokenString != "", self.submittedPushToken != tokenString else {
                apphudLog("Already submitted the same push token, exiting")
                callback?(true)
                return
            }
            let params: [String: String] = ["device_id": self.currentDeviceID, "push_token": tokenString]
            self.httpClient?.startRequest(path: .push, params: params, method: .put) { (result, _, _, _, _, _) in
                if result {
                    self.submittedPushToken = tokenString
                }
                callback?(result)
            }
        }
    }

    // MARK: - V2 API

    internal func trackDurationLogs(params: [[String: AnyHashable]], callback: @escaping () -> Void) {
        let result = performWhenUserRegistered {
            var final_params: [String: AnyHashable] = ["device_id": self.currentDeviceID,
                                                       "user_id": self.currentUserID,
                                                       "bundle_id": Bundle.main.bundleIdentifier,
                                                       "data": params]

            #if os(iOS)
            final_params["connection_type"] = self.currentReachabilityStatus.rawValue
            #endif

            self.httpClient?.startRequest(path: .logs, apiVersion: .APIV3, params: final_params, method: .post) { (_, _, _, _, _, _) in
                callback()
            }
        }
        if !result {
            apphudLog("Tried to send logs, but user not yet registered, adding to schedule")
        }
    }

    internal func trackEvent(params: [String: AnyHashable], callback: @escaping () -> Void) {
        let result = performWhenUserRegistered {
            let final_params: [String: AnyHashable] = ["device_id": self.currentDeviceID].merging(params, uniquingKeysWith: {(current, _) in current})
            self.httpClient?.startRequest(path: .events, apiVersion: .APIV2, params: final_params, method: .post) { (_, _, _, _, _, _) in
                callback()
            }
        }
        if !result {
            apphudLog("Tried to trackRuleEvent, but user not yet registered, adding to schedule")
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

        submitPaywallEvent(params: params) { (result, _, _, _, code, _) in
            if !result {
                self.schedulePaywallEvent(params, code == NSURLErrorNotConnectedToInternet)
            } else {
                self.paywallEventsRetriesCount = 0
            }
        }
    }

    private func schedulePaywallEvent(_ params: [String: AnyHashable], _ noInternetError: Bool) {
        guard httpClient != nil, httpClient!.canRetry else {
            return
        }
        guard paywallEventsRetriesCount < maxNumberOfPaywallEventsRetries else {
            apphudLog("Reached max number of paywall events retries \(paywallEventsRetriesCount). Exiting..", forceDisplay: true)
            return
        }

        let delay: TimeInterval

        if noInternetError {
            delay = 2.0
        } else {
            delay = 5.0
            paywallEventsRetriesCount += 1
        }

        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(trackPaywallEvent(params:)), object: nil)
        perform(#selector(trackPaywallEvent(params:)), with: params, afterDelay: delay)
        apphudLog("Scheduled paywall events retry in \(delay) seconds.", forceDisplay: true)
    }

    internal func submitPaywallEvent(params: [String: AnyHashable], callback: @escaping ApphudHTTPResponseCallback) {
        let result = performWhenUserRegistered {
            let environment = Apphud.isSandbox() ? ApphudEnvironment.sandbox.rawValue : ApphudEnvironment.production.rawValue
            let final_params: [String: AnyHashable] = ["device_id": self.currentDeviceID,
                                                       "user_id": self.currentUserID,
                                                       "timestamp": Date().currentTimestamp,
                                                       "environment": environment].merging(params, uniquingKeysWith: {(current, _) in current})

            self.httpClient?.startRequest(path: .events, apiVersion: .APIV1, params: final_params, method: .post, callback: callback)
        }
        if !result {
            apphudLog("Tried to trackPaywallEvent, but user not yet registered, adding to schedule")
        }
    }

    /// Not used yet
    internal func getRule(ruleID: String, callback: @escaping (ApphudRule?) -> Void) {

        let result = performWhenUserRegistered {
            let params = ["device_id": self.currentDeviceID] as [String: String]

            self.httpClient?.startRequest(path: .rule(ruleID), apiVersion: .APIV2, params: params, method: .get) { (result, response, _, _, _, _) in
                if result, let dataDict = response?["data"] as? [String: Any],
                    let ruleDict = dataDict["results"] as? [String: Any] {
                    callback(ApphudRule(dictionary: ruleDict))
                } else {
                    callback(nil)
                }
            }
        }
        if !result {
            apphudLog("Tried to getRule \(ruleID), but user not yet registered, adding to schedule")
        }
    }

    internal func checkForUnreadNotifications() {
        #if os(iOS)
        performWhenUserRegistered {
            let params = ["device_id": self.currentDeviceID] as [String: String]
            self.httpClient?.startRequest(path: .notifications, apiVersion: .APIV2, params: params, method: .get, callback: { (result, response, _, _, _, _) in

                if result, let dataDict = response?["data"] as? [String: Any], let notifArray = dataDict["results"] as? [[String: Any]], let notifDict = notifArray.first, var ruleDict = notifDict["rule"] as? [String: Any] {
                    let properties = notifDict["properties"] as? [String: Any]
                    ruleDict = ruleDict.merging(properties ?? [:], uniquingKeysWith: {_, new in new})
                    let rule = ApphudRule(dictionary: ruleDict)
                    ApphudRulesManager.shared.handleRule(rule: rule)
                }
            })
        }
        #endif
    }

    internal func readAllNotifications(for ruleID: String) {
        performWhenUserRegistered {
            let params = ["device_id": self.currentDeviceID, "rule_id": ruleID] as [String: String]
            self.httpClient?.startRequest(path: .readNotifications, apiVersion: .APIV2, params: params, method: .post, callback: { (_, _, _, _, _, _) in
            })
        }
    }

    internal func getActiveRuleScreens(_ callback: @escaping ([String]) -> Void) {
        performWhenUserRegistered {
            self.httpClient?.startRequest(path: .screens, apiVersion: .APIV2, params: nil, method: .get) { result, response, _, _, _, _ in
                if result, let dataDict = response?["data"] as? [String: Any], let screensIdsArray = dataDict["results"] as? [String] {
                    callback(screensIdsArray)
                } else {
                    callback([])
                }
            }
        }
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
