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
/// Identity version 1: set on every start, so a stored device id without it is a reinstall.
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
    @MainActor internal var pendingUserRegistrationCallbackCount: Int { userRegisteredCallbacks.count }
    private var addedObservers = false
    private var allowIdentifyUser = true

    // MARK: - Receipt and products properties

    @MainActor internal var storeKitProductsFetchedCallbacks = [ApphudErrorCallback]()
    // SK1 feeder task that populates the public `ApphudProduct.skProduct` property.
    // Legacy SKProduct-based APIs await it; paywall readiness does not.
    @MainActor internal var skProductsFeederTask: Task<Void, Never>?
    internal var customRegistrationAttemptsCount: Int?
    internal var submitReceiptRetries: ApphudRetryLog = (0, 0)
    @MainActor internal var submitReceiptCallbacks = [ApphudNSErrorCallback?]()
    internal var restorePurchasesCallback: (([ApphudSubscription]?, [ApphudNonRenewingPurchase]?, Error?) -> Void)?
    // Single-flight slot for receipt submission. Main-actor isolated because it decides
    // whether a transaction may be finished — it must not be read or written concurrently.
    @MainActor internal var submittingTransaction: String?
    // V2 restore waits for a false submission; its retry belongs to this session and upload.
    @MainActor internal var submittingReceiptRestore = false
    @MainActor internal var submittingReceiptID: UUID?
    @MainActor internal var submittingReceiptIdentity: ApphudIdentity?
    @MainActor internal var receiptSessionGeneration = UUID()
    @MainActor internal var observedTransactions = ApphudObservedTransactions()
    @MainActor internal var responseContext: ApphudIdentityContext?
    @MainActor internal var responseContextVersion: UInt64 = 0
    @MainActor internal var activeUserRegistrationID: UUID?
    @MainActor internal var restoreOperationCallbacks: [UUID: ApphudNSErrorCallback] = [:]
    internal let identityResponseCache = ApphudIdentityResponseCache()
    // A transaction check that arrived while a purchase was in flight; it runs once that
    // purchase completes, so the check is neither dropped nor polled for.
    @MainActor internal var deferredTransactionCheck = false
    // The SK2 store means "backend acknowledged — safe to finish". Pre-SK2 versions
    // persisted ids under "ApphudLastUploadedTransactions" BEFORE acknowledgment, so
    // that key may name purchases that never reached Apphud and must not be read here:
    // an inherited id would finish a paid transaction without ever submitting it.
    @MainActor internal var lastUploadedTransactions: [UInt64] {
        get {
            UserDefaults.standard.array(forKey: "ApphudLastUploadedTransactionsSK2") as? [UInt64] ?? [UInt64]()
        }
        set {
            UserDefaults.standard.set(newValue, forKey: "ApphudLastUploadedTransactionsSK2")
        }
    }

    // MARK: - Paywalls Events
    internal var lastUploadedPaywallEvent = [String: AnyHashable]()
    internal var lastUploadedPaywallEventDate: Date?
    internal var observerModePurchaseIdentifiers: (paywall: String, placement: String?)?

    // MARK: - User registering properties
    /// The identity model of this launch, chosen by the first start.
    internal var identityVersion: ApphudIdentityVersion = .v1 {
        didSet { identityVersionChosen = true }
    }
    private var identityVersionChosen = false
    internal var isIdentityV1: Bool { identityVersion == .v1 }
    /// Identity version 1: the device id, as SDK 4.6 kept it.
    internal var currentDeviceID: String = ""
    /// Identity version 1: the user id, as SDK 4.6 kept it.
    internal var v1UserID: String = ""
    /// Identity version 1: `reinstall: true` goes in one registration per process.
    internal var reinstallTracked: Bool = false
    internal var identityStore = ApphudIdentityStore()
    /// One per install: new after a reinstall, kept across logout. Replaces the old device id.
    internal var currentInstallationID: String = ""
    /// The anonymous person: new after logout or a reinstall.
    internal var currentAnonymousID: String = ""
    /// The app's own user id, set by identify; `nil` while anonymous.
    internal var identifiedUserID: String?
    /// `true` reinstall, `false` first install, `nil` not known.
    internal var isReinstall: Bool?
    /// Version 2 started with every id from the app: the app owns the reinstall answer.
    internal var appSuppliesIDs = false
    /// The user once identified, the anonymous person before. Version 1: its user id.
    internal var currentUserID: String { isIdentityV1 ? v1UserID : (identifiedUserID ?? currentAnonymousID) }

    internal var identity: ApphudIdentity {
        get {
            ApphudIdentity(installationID: currentInstallationID, anonymousID: currentAnonymousID,
                           userID: identifiedUserID, isReinstall: isReinstall)
        }
        set {
            currentInstallationID = newValue.installationID
            currentAnonymousID = newValue.anonymousID
            identifiedUserID = newValue.userID
            isReinstall = newValue.isReinstall
        }
    }

    /// Identity fields for a request; `user_id` only once the app identified the user. Version 1:
    /// `device_id`, and `user_id` wherever SDK 4.6 sent it.
    internal func identityParams(includeUserID: Bool = false) -> [String: String] {
        if isIdentityV1 {
            var params = ["device_id": currentDeviceID]
            if includeUserID {
                params["user_id"] = currentUserID
            }
            return params
        }
        var params = identity.requestParams
        if includeUserID, let identifiedUserID {
            params["user_id"] = identifiedUserID
        }
        return params
    }
    /// Nonisolated mirror of `currentUser?.internalId` for use from HTTP client (non-MainActor).
    internal var currentCustomerID: String = ""
    internal var storefrontCurrency: ApphudCurrency?

    internal var isPremium: Bool = false
    internal var hasActiveSubscription: Bool = false

    @MainActor internal var currentUser: ApphudUser? {
        didSet {
            self.currentCustomerID = currentUser?.internalId ?? ""
            self.updatePremiumStatus(user: currentUser)
        }
    }
    @MainActor internal var paywalls = [ApphudPaywall]()
    @MainActor internal var placements = [ApphudPlacement]()
    @MainActor internal var permissionGroups: [ApphudGroup]?

    internal var delayedInitilizationParams: (apiKey: String, supplied: ApphudSuppliedIDs, observerMode: Bool)?
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
    /// A registration of this launch failed; see `awaitsVersion1Registration`.
    internal var version1LaunchRegistrationEnded = false
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
                var cachedIDFA: String?
                var cachedIDFV: String?
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

    internal var purchasingFromScreen: Bool = false
    internal var purchasingProduct: ApphudProduct?
    internal var pendingTransactionID: String?
    internal var fallbackMode = false
    internal var registrationStartedAt: Date?
    @MainActor internal var currencyTaskFinished = false
    internal var initialRequestID = UUID().uuidString

    var webController: ApphudWebController? = nil
    @MainActor internal var deeplinkAttributionHandler: ApphudDeeplinkHandler?
    
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

    /// Read once per launch: a later start (after logout, or a delayed one) keeps the first choice.
    internal func chooseIdentityVersion(_ version: ApphudIdentityVersion) {
        if !identityVersionChosen {
            identityVersionChosen = true
            identityVersion = version
        } else if version != identityVersion {
            apphudLog("identityVersion is read once per launch: .v\(identityVersion.rawValue) stays until the next launch", forceDisplay: true)
        }
    }

    @MainActor
    internal func initialize(apiKey: String, supplied: ApphudSuppliedIDs, observerMode: Bool, identityVersion: ApphudIdentityVersion = .v1) {

        chooseIdentityVersion(identityVersion)

        // The session's launch rule and lifecycle observers start here, not at the first request.
        ApphudSession.shared.takeForeground(ifActive: ApphudSession.isAppActive())

        #if os(iOS) || os(tvOS)
        // Before the first unlock nothing stored can be read; a new install also needs the Keychain.
        let storedIDsUnreadable = isIdentityV1
            ? !ApphudKeychain.canUseKeychain && !ApphudKeychain.hasLocalStorageData
            : !UIApplication.shared.isProtectedDataAvailable && !identityStore.hasInstallRecord
        if storedIDsUnreadable && UIApplication.shared.applicationState != .active {
            setupObservers()
            apphudLog("Unable to initialize right now, will wait until app becomes active", forceDisplay: true)
            self.delayedInitilizationParams = (apiKey, supplied, observerMode)
            return
        }
        #endif

        if httpClient == nil {
            ApphudStoreKitWrapper.shared.setupObserver()
            httpClient = ApphudHttpClient.shared
            if #available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *) {
                // Start Transaction.updates and PurchaseIntent listeners with the SDK,
                // not lazily — purchase intents must be caught from launch.
                ApphudAsyncStoreKit.shared.startObserving()
            }
        }

        httpClient!.apiKey = apiKey
        apphudLog("Started Apphud SDK (\(ApphudHttpClient.shared.sdkVersion))", forceDisplay: true)

        guard allowIdentifyUser == true else {
            apphudLog("Abort initializing, because Apphud SDK already initialized. You can only call `Apphud.start()` once per app lifecycle. Or if `Apphud.logout()` was called previously.", forceDisplay: true)
            return
        }
        allowIdentifyUser = false

        if isIdentityV1 {
            #if DEBUG
            if supplied.anonymousID != nil || supplied.isReinstall != nil || (supplied.installationID != nil && supplied.installationID != supplied.deviceID) {
                apphudLog("anonymousID, installationID and isReinstall are used with identityVersion .v2 only", forceDisplay: true)
            }
            #endif
            identifyV1(inputUserID: supplied.userID, inputDeviceID: supplied.deviceID, observerMode: observerMode)
        } else {
            identify(apiKey: apiKey, supplied: supplied, observerMode: observerMode)
        }
    }

    /// The app's reinstall answer that arrived after `start`: the next registration carries a reinstall
    /// until one carrying it succeeds.
    @MainActor
    internal func setReinstall(_ isReinstall: Bool) {
        // `start` waits for the first unlock: the answer goes with it.
        if !isIdentityV1, delayedInitilizationParams?.supplied.suppliesAllIDs == true {
            delayedInitilizationParams?.supplied.isReinstall = isReinstall
            return
        }
        guard !isIdentityV1, appSuppliesIDs else {
            #if DEBUG
            apphudLog("setReinstall is used after a start with identityVersion .v2, installationID and anonymousID only", forceDisplay: true)
            #endif
            return
        }
        self.isReinstall = isReinstall
        identityStore.keepReinstallAnswer(isReinstall, installationID: currentInstallationID)
    }

    /// Identity version 1: the ids as SDK 4.6 resolved them.
    @MainActor
    internal func identifyV1(inputUserID: String?, inputDeviceID: String? = nil, observerMode: Bool) {
        ApphudUtils.shared.storeKitObserverMode = observerMode

        // Version 2 ran last: its user id (or anonymous id) finds the same customer.
        let fromVersion2 = identityStore.idsForVersion1()
        version1LaunchRegistrationEnded = false
        if let fromVersion2 {
            if let deviceID = fromVersion2.deviceID {
                ApphudKeychain.saveDeviceID(deviceID: deviceID)
            }
            ApphudKeychain.saveUserID(userID: fromVersion2.userID)
            // The install ran before: no reinstall.
            UserDefaults.standard.set(ApphudFlagString, forKey: ApphudFlagString)
        }

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
            self.v1UserID = inputUserID!
        } else if let fromVersion2 {
            self.v1UserID = fromVersion2.userID
        } else if let existingUserID = cachedUser?.userId {
            self.v1UserID = existingUserID
        } else if userIDFromKeychain != nil {
            self.v1UserID = userIDFromKeychain!
        } else {
            self.v1UserID = generatedUUID
        }

        identityStore.markVersion1(tookOverVersion2: fromVersion2 != nil)

        self.currentUser = cachedUser

        Task.detached {
            await self.currentUser?.updateProductTypes()
            await self.updatePremiumStatus(user: self.currentUser)
        }

        self.initDate = Date()

        Task(priority: .userInitiated) {

            // After version 2 a registration must show the backend this device id, on a later launch too
            // if the first one failed.
            var isIdenticalUserIds = !self.identityStore.isVersion1RegistrationPending
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

    @MainActor
    internal func identify(apiKey: String, supplied: ApphudSuppliedIDs, observerMode: Bool) {
        ApphudUtils.shared.storeKitObserverMode = observerMode

        guard let resolution = identityStore.resolve(supplied) else {
            // The stored ids can't be read yet (before the first unlock): never mint new ones over them.
            apphudLog("Unable to read the stored ids right now, will wait until app becomes active", forceDisplay: true)
            setupObservers()
            allowIdentifyUser = true
            delayedInitilizationParams = (apiKey, supplied, observerMode)
            return
        }

        identity = resolution.identity
        appSuppliesIDs = supplied.suppliesAllIDs
        (isFreshInstall, isRedownload) = Self.launchFlags(resolution)
        holdRequestsIfTheBackendDoesNotKnowThisInstallation()
        #if DEBUG
        if resolution.switchedUser {
            apphudLog("Started with another user without logout. Call Apphud.logout() before a different user signs in.", forceDisplay: true)
        }
        #endif

        setupObservers()

        let cachedUser = ApphudUser.fromCacheV2()

        self.currentUser = cachedUser

        Task.detached {
            await self.currentUser?.updateProductTypes()
            await self.updatePremiumStatus(user: self.currentUser)
        }

        self.initDate = Date()

        Task(priority: .userInitiated) {

            // Ids the backend hasn't seen yet (a new install, an upgrade, an identify whose request
            // failed) must reach it: registration is not skipped then.
            let isIdenticalUserIds = !self.identityStore.isSyncPending

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

    /// `is_new` and the first-launch metrics: only the install's first launch counts, so later
    /// launches of a reinstall don't.
    internal static func launchFlags(_ resolution: ApphudIdentityResolution) -> (isFreshInstall: Bool, isRedownload: Bool) {
        let firstLaunch = resolution.launch == .newInstall
        return (firstLaunch, firstLaunch && resolution.identity.isReinstall == true)
    }

    @MainActor private func skipRegistration(isIdenticalUserIds: Bool, hasCashedUser: Bool, hasCachedPaywalls: Bool) -> Bool {
        return isIdenticalUserIds && hasCashedUser && hasCachedPaywalls && !isUserCacheExpired() && !isUserPaid()
    }

    @MainActor private func isUserPaid() -> Bool {
       return self.currentUser?.subscriptions.count ?? 0 > 0 || self.currentUser?.purchases.count ?? 0 > 0
    }

    internal var cacheTimeout: TimeInterval = apphudIsSandbox() ? 5 : 90000
    internal func setCacheTimeout(_ value: TimeInterval) {
        if value >= 0 && value < 86_400*2 {
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

    @MainActor
    internal func continueToRegisteringUser(skipRegistration: Bool = false, needToUpdateProductGroups: Bool = true) {
        guard !isRegisteringUser else {return}
        guard self.httpClient != nil else {return}
        isRegisteringUser = true

        registerUser(skipRegistration: skipRegistration)
    }

    @MainActor
    @objc private func registerUser(skipRegistration: Bool = false) {
        let context = userResponseContext()
        let registrationID = context == nil ? nil : UUID()
        if let registrationID {
            activeUserRegistrationID = registrationID
            isRegisteringUser = true
        }
        Task.detached(priority: .userInitiated) {
            let response = await self.createOrGetUser(initialCall: true, skipRegistration: skipRegistration, responseContext: context)
            if let context {
                await self.completeVersion2Registration(response, context: context, registrationID: registrationID!)
                return
            }

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

    @MainActor
    private func completeVersion2Registration(_ response: (Bool, Int), context: ApphudIdentityContext, registrationID: UUID) {
        guard activeUserRegistrationID == registrationID else { return }
        activeUserRegistrationID = nil
        isRegisteringUser = false
        guard isCurrentUserResponse(context) else { return }
        if response.0 {
            userRegisterRetries = (0, 0)
            apphudLog("User successfully registered with id: \(currentUserID)", forceDisplay: true)
            performAllUserRegisteredBlocks(responseContext: context)
            checkForUnreadNotifications()
            migrateiOS14PurchasesIfNeeded()
            perform(#selector(forceSendAttributionDataIfNeeded), with: nil, afterDelay: 10)
        } else {
            scheduleUserRegistering(errorCode: response.1)
        }
        if isApplicationActive && !didHandleBecomeActive { handleDidBecomeActive() }
    }

    private func willRetryUserRegistration() -> Bool {
        userRegisterRetries.count < maxNumberOfUserRegisterRetries
    }

    @MainActor
    private func scheduleUserRegistering(errorCode: Int) {
        endVersion1LaunchRegistration()
        // Registration will not be retried: release everything waiting on it, otherwise
        // callers that allow failure (a transaction submission, for one) wait forever.
        guard httpClient != nil, httpClient!.canRetry else {
            performAllUserFailedBlocks()
            return
        }
        guard willRetryUserRegistration() else {
            apphudLog("Reached max number of user register retries \(userRegisterRetries.count). Exiting..", forceDisplay: true)
            performAllUserFailedBlocks()
            return
        }

        let retryImmediately = [NSURLErrorRedirectToNonExistentLocation, NSURLErrorUnknown, NSURLErrorTimedOut, NSURLErrorNetworkConnectionLost]
        let noInternetError = [NSURLErrorNotConnectedToInternet, NSURLErrorCannotConnectToHost, NSURLErrorCannotFindHost]

        var delay: TimeInterval = 0

        let serverIsUnreachable = [NSURLErrorCannotConnectToHost, NSURLErrorTimedOut, 500, 502, 503].contains(errorCode)
        let hostUnreachable = [NSURLErrorCannotConnectToHost, NSURLErrorTimedOut, NSURLErrorCannotFindHost, NSURLErrorDNSLookupFailed, NSURLErrorSecureConnectionFailed].contains(errorCode)

        userRegisterRetries.count += 1
        userRegisterRetries.errorCode = errorCode

        let maxAttempts = min(self.customRegistrationAttemptsCount ?? APPHUD_DEFAULT_RETRIES, APPHUD_DEFAULT_RETRIES)

        // The main gateway host is unreachable (e.g. blocked in certain regions). Try to fetch an
        // alternative host from the remote fallback file and, if switched, retry registration immediately.
        if hostUnreachable {
            Task { @MainActor in
                if await self.httpClient?.loadFallbackHostIfNeeded() == true {
                    NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(self.registerUser), object: nil)
                    self.registerUser()
                }
            }
        }

        if serverIsUnreachable && (userRegisterRetries.count >= maxAttempts || Date().timeIntervalSince(initDate) > APPHUD_MAX_INITIAL_LOAD_TIME) {
            executeFallback(callback: nil)
        }

        if userRegisterRetries.count >= maxAttempts && currentUser == nil || currentUser != nil {
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
            ApphudScreensManager.shared.handlePendingAPSInfo()
        }
        #endif
    }

    @MainActor
    @objc private func handleDidBecomeActive() {

        didHandleBecomeActive = true

        apphudLog("App did become active")

        if let delayedParams = delayedInitilizationParams {
            // Cleared first: a start that still can't read the stored ids delays itself again.
            delayedInitilizationParams = nil
            initialize(apiKey: delayedParams.apiKey, supplied: delayedParams.supplied, observerMode: delayedParams.observerMode,
                       identityVersion: identityVersion)
        }

        checkPendingRules()
        checkTransactionsNow()

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
    internal func performWhenUserRegistered(allowFailure: Bool = false, callback: @escaping ApphudVoidMainCallback) {
        // detach to call in the next run loop
        Task.detached { @MainActor in
            if self.currentUser != nil && !self.awaitsVersion1Registration {
                callback()
            } else if allowFailure, let client = self.httpClient, !client.canRetry {
                // Registration will never be retried (invalid API key / unauthorized):
                // a failure-tolerant caller must not wait forever.
                callback()
            } else {
                if self.userRegisterRetries.count >= self.maxNumberOfUserRegisterRetries {
                    self.continueToRegisteringUser()
                }

                self.userRegisteredCallbacks.append((callback, allowFailure))
            }
        }
    }

    /// Identity version 1 took the ids of version 2 over and no registration of it has succeeded yet:
    /// the backend may not know its device id. The cached customer still shows, requests wait for the
    /// first registration of this launch.
    internal var awaitsVersion1Registration: Bool {
        isIdentityV1 && !version1LaunchRegistrationEnded && identityStore.isVersion1RegistrationPending
    }

    /// The first registration of this launch failed: with a cached customer, what waited for it goes, as
    /// in SDK 4.6; without one it keeps waiting for a registration, as in SDK 4.6.
    @MainActor
    internal func endVersion1LaunchRegistration() {
        guard awaitsVersion1Registration else { return }
        version1LaunchRegistrationEnded = true
        if currentUser != nil {
            performAllUserRegisteredBlocks()
        }
    }

    /// `legacy_device_id` still to be sent (the first launch after an update): requests wait until the
    /// backend knows this installation.
    internal func holdRequestsIfTheBackendDoesNotKnowThisInstallation() {
        if identityStore.registrationReport(for: identity).legacyDeviceID != nil {
            ApphudHttpClient.shared.firstRegistrationHold.close()
        }
    }

    internal func performAllUserRegisteredBlocks(responseContext: ApphudIdentityContext? = nil) {
        // detach to call in the next run loop
        Task.detached { @MainActor in
            guard self.isCurrentUserResponse(responseContext) else { return }
            while !self.userRegisteredCallbacks.isEmpty {
                self.userRegisteredCallbacks.removeFirst().block()
            }
        }
    }

    internal func performAllUserFailedBlocks() {
        // detach to call in the next run loop
        Task.detached { @MainActor in
            for tuple in self.userRegisteredCallbacks {
                if tuple.allowFailure {
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
            var params = self.identityParams()
            params["push_token"] = tokenString
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
            var final_params: [String: AnyHashable] = self.identityParams(includeUserID: true)
            final_params["bundle_id"] = Bundle.main.bundleIdentifier
            final_params["data"] = params

            #if os(iOS)
            final_params["connection_type"] = self.currentReachabilityStatus.rawValue
            #endif

            self.httpClient?.startRequest(path: .logs, apiVersion: .APIV4, params: final_params, method: .post) { (_, _, _, _, _, _, _) in
                callback()
            }
        }
    }

    internal func trackEvent(params: [String: AnyHashable], callback: @escaping () -> Void) {
        performWhenUserRegistered {
            let identityParams: [String: AnyHashable] = self.identityParams()
            let final_params = identityParams.merging(params, uniquingKeysWith: {(current, _) in current})
            self.httpClient?.startRequest(path: .events, apiVersion: .APIV4, params: final_params, method: .post) { (_, _, _, _, _, _, _) in
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
            var eventParams: [String: AnyHashable] = self.identityParams(includeUserID: true)
            eventParams["timestamp"] = Date().currentTimestamp
            eventParams["environment"] = environment
            let final_params = eventParams.merging(params, uniquingKeysWith: {(current, _) in current})

            self.httpClient?.startRequest(path: .events, apiVersion: .APIV4, params: final_params, method: .post, retry: true, callback: callback)
        }
    }

    internal func checkForUnreadNotifications() {
        #if os(iOS)
        performWhenUserRegistered {
            let params = self.identityParams()
            self.httpClient?.startRequest(path: .notifications, apiVersion: .APIV4, params: params, method: .get, callback: { (result, response, _, _, _, _, _) in

                if result, let dataDict = response?["data"] as? [String: Any], let notifArray = dataDict["results"] as? [[String: Any]], let notifDict = notifArray.first, var ruleDict = notifDict["rule"] as? [String: Any] {
                    let properties = notifDict["properties"] as? [String: Any]
                    ruleDict = ruleDict.merging(properties ?? [:], uniquingKeysWith: {_, new in new})
                    let rule = ApphudRule(dictionary: ruleDict)
                    Task { @MainActor in
                        ApphudScreensManager.shared.handleRule(rule: rule)
                    }
                }
            })
        }
        #endif
    }

    internal func readAllNotifications(for ruleID: String) {
        performWhenUserRegistered {
            var params = self.identityParams()
            params["rule_id"] = ruleID
        self.httpClient?.startRequest(path: .readNotifications, apiVersion: .APIV4, params: params, method: .post, callback: { (_, _, _, _, _, _, _) in
            })
        }
    }

    internal func getActiveRuleScreens(_ callback: @escaping ([String]) -> Void) {
        performWhenUserRegistered {
            self.httpClient?.startRequest(path: .screens, apiVersion: .APIV4, params: nil, method: .get) { result, response, _, _, _, _, _ in
                if result, let dataDict = response?["data"] as? [String: Any], let screensIdsArray = dataDict["results"] as? [String] {
                    callback(screensIdsArray)
                } else {
                    callback([])
                }
            }
        }
    }

    /// Before a start in this launch, the version that ran last here decides how to log out.
    internal var logoutRunsVersion1: Bool {
        identityVersionChosen ? isIdentityV1 : identityStore.lastIdentityVersion != .v2
    }

    internal func logout(anonymousID: String? = nil) async {
        if logoutRunsVersion1 {
            await logoutV1()
            return
        }

        // A new anonymous person (the supplied id, or a fresh one), no user; the installation and
        // the Keychain reinstall key stay. Saved and switched in one main-actor step together with
        // `currentUser` and the waiting callbacks, so a kill during logout doesn't bring the previous
        // user back.
        let cacheVersion = await MainActor.run {
            var identity = self.identity
            identityStore.logout(anonymousID: anonymousID, &identity)
            self.identity = identity
            currencyTaskFinished = false
            paywalls.removeAll()
            placements.removeAll()
            currentUser = nil
            isPremium = false
            hasActiveSubscription = false
            // Answer everyone still waiting before clearing: a dropped callback leaves
            // its awaiting continuation (a purchase call, for one) suspended forever.
            let logoutError = ApphudError(message: "Apphud SDK was logged out")
            receiptSessionGeneration = UUID()
            activeUserRegistrationID = nil
            observedTransactions.reset()
            cancelVersion2Restores(error: logoutError)
            userRegisteredCallbacks.forEach { tuple in
                if tuple.allowFailure { tuple.block() }
            }
            userRegisteredCallbacks.removeAll()
            storeKitProductsFetchedCallbacks.forEach { $0(logoutError) }
            storeKitProductsFetchedCallbacks.removeAll()
            submittingReceiptID = nil
            submittingReceiptIdentity = nil
            submittingReceiptRestore = false
            submitReceiptCallbacks.forEach { $0?(logoutError) }
            submitReceiptCallbacks.removeAll()
            lastUploadedTransactions = []
            submittingTransaction = nil
            // Answer and clear in the same main-actor step: doing it outside would run
            // on a background executor and could race a drain-scheduled invocation
            // into calling the host's completion twice.
            restorePurchasesCallback?(nil, nil, logoutError)
            restorePurchasesCallback = nil
            return userResponseContext()!.version
        }

        await identityResponseCache.clear(version: cacheVersion)
        await ApphudDataActor.shared.clear()

        await ApphudUser.clearCache()

        /** Permissions groups never change, no need to clear from cache.
        apphudDataClearCache(key: ApphudProductGroupsCacheKey)
        permissionGroups = nil
        */

        await ApphudDataActor.shared.apphudDataClearCache(key: ApphudPaywallsCacheKey)
        await ApphudDataActor.shared.apphudDataClearCache(key: ApphudPlacementsCacheKey)

        // A response that was in flight when logout started may have brought the previous customer back.
        await MainActor.run { currentUser = nil }

        didPreparePaywalls = false

        submitReceiptRetries = (0, 0)
        lastUploadedPaywallEvent.removeAll()
        lastUploadedPaywallEventDate = nil
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

        // The next customer's first request starts a new session.
        ApphudSession.shared.startNewSessionOnLogout()

        allowIdentifyUser = true
        apphudLog("User logged out. Apphud SDK is uninitialized.", logLevel: .all)
    }

    /// Identity version 1: logout as SDK 4.6 did it. The next start generates a new device id and user id.
    private func logoutV1() async {

        await ApphudDataActor.shared.clear()
        await MainActor.run {
            // Only when the ids are reset: with the Keychain unavailable 4.6.1 keeps them. Marked first:
            // a crash in between must not bring the person before the logout back.
            if ApphudKeychain.canUseKeychain {
                identityStore.markVersion1LoggedOut()
            }
            ApphudKeychain.resetValues()
        }

        await ApphudUser.clearCache()
        v1UserID = ""
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
            // Answer everyone still waiting before clearing: a dropped callback leaves
            // its awaiting continuation (a purchase call, for one) suspended forever.
            let logoutError = ApphudError(message: "Apphud SDK was logged out")
            userRegisteredCallbacks.forEach { tuple in
                if tuple.allowFailure { tuple.block() }
            }
            userRegisteredCallbacks.removeAll()
            storeKitProductsFetchedCallbacks.forEach { $0(logoutError) }
            storeKitProductsFetchedCallbacks.removeAll()
            receiptSessionGeneration = UUID()
            observedTransactions.reset()
            submittingReceiptID = nil
            submittingReceiptIdentity = nil
            submittingReceiptRestore = false
            submitReceiptCallbacks.forEach { $0?(logoutError) }
            submitReceiptCallbacks.removeAll()
            lastUploadedTransactions = []
            submittingTransaction = nil
            // Answer and clear in the same main-actor step: doing it outside would run
            // on a background executor and could race a drain-scheduled invocation
            // into calling the host's completion twice.
            restorePurchasesCallback?(nil, nil, logoutError)
            restorePurchasesCallback = nil
        }

        didPreparePaywalls = false

        submitReceiptRetries = (0, 0)
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

        // The next customer's first request starts a new session.
        ApphudSession.shared.startNewSessionOnLogout()

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
