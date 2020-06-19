//
//  ApphudInternal.swift
//  subscriptionstest
//
//  Created by ren6 on 01/07/2019.
//  Copyright © 2019 apphud. All rights reserved.
//

import Foundation
import AdSupport
import StoreKit

internal typealias HasPurchasesChanges = (hasSubscriptionChanges: Bool, hasNonRenewingChanges: Bool)

@available(iOS 11.2, *)
final class ApphudInternal: NSObject {

    fileprivate let requiresReceiptSubmissionKey = "requiresReceiptSubmissionKey"
    fileprivate let didSubmitAppsFlyerAttributionKey = "didSubmitAppsFlyerAttributionKey"
    fileprivate let didSubmitFacebookAttributionKey = "didSubmitFacebookAttributionKey"
    fileprivate let didSubmitAdjustAttributionKey = "didSubmitAdjustAttributionKey"

    static let shared = ApphudInternal()
    weak var delegate: ApphudDelegate?
    weak var uiDelegate: ApphudUIDelegate?
    var currentUser: ApphudUser?
    var currentDeviceID: String = ""
    var currentUserID: String = ""
    fileprivate var isSubmittingReceipt: Bool = false

    private var lastCheckDate = Date()

    var httpClient: ApphudHttpClient!

    private var addedObservers = false

    fileprivate var userRegisteredCallbacks = [ApphudVoidCallback]()
    fileprivate var productGroupsFetchedCallbacks = [ApphudVoidCallback]()

    private var productsGroupsMap: [String: String]?

    private var submitReceiptCallback: ((Error?) -> Void)?

    private var restorePurchasesCallback: (([ApphudSubscription]?, [ApphudNonRenewingPurchase]?, Error?) -> Void)?

    private var allowInitialize = true

    private var userRegisterRetriesCount: Int = 0
    private let maxNumberOfUserRegisterRetries: Int = 10

    private var isRegisteringUser = false {
        didSet(newValue) {
            if newValue == true {
                NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(continueToRegisteringUser), object: nil)
            }
        }
    }
    private var isSendingAppsFlyer = false
    private var isSendingAdjust = false

    private var didSubmitAppsFlyerAttribution: Bool {
        get {
            UserDefaults.standard.bool(forKey: didSubmitAppsFlyerAttributionKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: didSubmitAppsFlyerAttributionKey)
        }
    }

    private var didSubmitFacebookAttribution: Bool {
        get {
            UserDefaults.standard.bool(forKey: didSubmitFacebookAttributionKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: didSubmitFacebookAttributionKey)
        }
    }

    private var didSubmitAdjustAttribution: Bool {
        get {
            UserDefaults.standard.bool(forKey: didSubmitAdjustAttributionKey)
        }
        set {
            UserDefaults.standard.set(newValue, forKey: didSubmitAdjustAttributionKey)
        }
    }

    internal func initialize(apiKey: String, userID: String?, deviceIdentifier: String? = nil) {

        guard allowInitialize == true else {
            apphudLog("Abort initializing, because Apphud SDK already initialized.", forceDisplay: true)
            return
        }
        allowInitialize = false

        apphudLog("Started Apphud SDK (\(apphud_sdk_version))", forceDisplay: true)

        ApphudStoreKitWrapper.shared.setupObserver()

        var deviceID = ApphudKeychain.loadDeviceID()

        if deviceIdentifier != nil {
            deviceID = deviceIdentifier
        }

        if deviceID == nil {
            deviceID = ApphudKeychain.generateUUID()
            ApphudKeychain.saveDeviceID(deviceID: deviceID!)
        }

        self.currentDeviceID = deviceID!

        self.httpClient = ApphudHttpClient.shared
        self.httpClient.apiKey = apiKey

        self.currentUser = ApphudUser.fromCache()
        let userIDFromKeychain = ApphudKeychain.loadUserID()

        if userID != nil {
            self.currentUserID = userID!
        } else if let existingUserID = self.currentUser?.user_id {
            self.currentUserID = existingUserID
        } else if userIDFromKeychain != nil {
            self.currentUserID = userIDFromKeychain!
        } else {
            self.currentUserID = ApphudKeychain.generateUUID()
        }

        if self.currentUserID != userIDFromKeychain {
            ApphudKeychain.saveUserID(userID: self.currentUserID)
        }

        self.productsGroupsMap = apphudFromUserDefaultsCache(key: "productsGroupsMap")

        continueToRegisteringUser()
    }

    @objc private func continueToRegisteringUser() {
        guard !isRegisteringUser else {return}
        isRegisteringUser = true

        createOrGetUser(shouldUpdateUserID: true) { success in

            self.isRegisteringUser = false
            self.setupObservers()

            if success {
                apphudLog("User successfully registered with id: \(self.currentUserID)", forceDisplay: true)
                self.performAllUserRegisteredBlocks()
                self.checkForUnreadNotifications()
            } else {
                self.scheduleUserRegistering()
            }
            // try to continue anyway, because maybe already has cached data, try to fetch storekit products
            self.continueToFetchProducts()
        }
    }

    private func scheduleUserRegistering() {
        guard userRegisterRetriesCount < maxNumberOfUserRegisterRetries else {
            apphudLog("Reached max number of user register retries \(userRegisterRetriesCount). Exiting..", forceDisplay: true)
            return
        }
        userRegisterRetriesCount += 1
        let delay: TimeInterval = TimeInterval(userRegisterRetriesCount * 5)
        perform(#selector(continueToRegisteringUser), with: nil, afterDelay: delay)
        apphudLog("Scheduled user register retry in \(delay) seconds.", forceDisplay: true)
    }

    private func continueToFetchProducts() {
        self.getProducts(callback: { (productsGroupsMap) in
            // perform even if productsGroupsMap is nil or empty
            self.performAllProductGroupsFetchedCallbacks()

            if productsGroupsMap?.keys.count ?? 0 > 0 {
                self.productsGroupsMap = productsGroupsMap
                apphudLog("Products groups fetched: \(self.productsGroupsMap as AnyObject)")
                apphudToUserDefaultsCache(dictionary: self.productsGroupsMap!, key: "productsGroupsMap")
            }
            // continue to fetch storekit products anyway
            self.continueToFetchStoreKitProducts()
        })
    }

    private func continueToFetchStoreKitProducts() {

        guard self.productsGroupsMap?.keys.count ?? 0 > 0 else {
            return
        }
        ApphudStoreKitWrapper.shared.fetchProducts(identifiers: Set(self.productsGroupsMap!.keys)) { _ in
            self.continueToUpdateProductPrices()
        }
    }

    private func continueToUpdateProductPrices() {
        let products = ApphudStoreKitWrapper.shared.products
        if products.count > 0 {
            self.updateUserCurrencyIfNeeded(priceLocale: products.first?.priceLocale)
            self.continueToUpdateProductsPrices(products: products)
        }
    }

    internal func refreshStoreKitProductsWithCallback(callback: (([SKProduct]) -> Void)?) {

        ApphudStoreKitWrapper.shared.customProductsFetchedBlock = callback

        if self.currentUser == nil {
            continueToRegisteringUser()
        } else if let productIDs = self.productsGroupsMap?.keys, productIDs.count > 0 {
            continueToFetchStoreKitProducts()
        } else {
            continueToFetchProducts()
        }
    }

    private func continueToUpdateProductsPrices(products: [SKProduct]) {
        self.submitProducts(products: products) { (_, _, _, _) in
        }
    }

    private func setupObservers() {
        if !addedObservers {
            NotificationCenter.default.addObserver(self, selector: #selector(handleDidBecomeActive), name: UIApplication.didBecomeActiveNotification, object: nil)
            addedObservers = true
        }
    }

    @objc private func handleDidBecomeActive() {

        let minCheckInterval: Double = 30

        performWhenUserRegistered {
            ApphudRulesManager.shared.handlePendingAPSInfo()
        }

        DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
            if self.currentUser == nil {
                self.continueToRegisteringUser()
            } else if Date().timeIntervalSince(self.lastCheckDate) > minCheckInterval {
                self.checkForUnreadNotifications()
                self.refreshCurrentUser()
            }
        }
    }

    @discardableResult private func parseUser(_ dict: [String: Any]?) -> HasPurchasesChanges {

        guard let dataDict = dict?["data"] as? [String: Any] else {
            return (false, false)
        }
        guard let userDict = dataDict["results"] as? [String: Any] else {
            return (false, false)
        }

        let oldStates = self.currentUser?.subscriptionsStates()
        let oldPurchasesStates = self.currentUser?.purchasesStates()

        self.currentUser = ApphudUser(dictionary: userDict)

        let newStates = self.currentUser?.subscriptionsStates()
        let newPurchasesStates = self.currentUser?.purchasesStates()

        ApphudUser.toCache(userDict)

        checkUserID(tellDelegate: true)

        /**
         If user previously didn't have subscriptions or subscriptions states don't match, or subscription product identifiers don't match
         */
        let hasSubscriptionChanges = (oldStates != newStates && self.currentUser?.subscriptions != nil)
        let hasPurchasesChanges = (oldPurchasesStates != newPurchasesStates && self.currentUser?.purchases != nil)
        return (hasSubscriptionChanges, hasPurchasesChanges)
    }

    private func checkUserID(tellDelegate: Bool) {
        guard let userID = self.currentUser?.user_id else {return}
        if self.currentUserID != userID {
            self.currentUserID = userID
            ApphudKeychain.saveUserID(userID: self.currentUserID)
            if tellDelegate {
                self.delegate?.apphudDidChangeUserID?(userID)
            }
        }
    }

    // MARK: Helper
    /// Returns false if current user is not yet registered, block is added to array and will be performed later.
    @discardableResult internal func performWhenUserRegistered(callback : @escaping ApphudVoidCallback) -> Bool {
        if currentUser != nil {
            callback()
            return true
        } else {
            userRegisteredCallbacks.append(callback)
            return false
        }
    }

    private func performAllUserRegisteredBlocks() {
        for block in userRegisteredCallbacks {
            apphudLog("Performing scheduled block..")
            block()
        }
        if userRegisteredCallbacks.count > 0 {
            apphudLog("All scheduled blocks performed, removing..")
            userRegisteredCallbacks.removeAll()
        }
    }

    /// Returns false if products groups map dictionary not yet received, block is added to array and will be performed later.
    @discardableResult internal func performWhenProductGroupsFetched(callback : @escaping ApphudVoidCallback) -> Bool {
        if self.productsGroupsMap != nil {
            callback()
            return true
        } else {
            productGroupsFetchedCallbacks.append(callback)
            return false
        }
    }

    private func performAllProductGroupsFetchedCallbacks() {
        for block in productGroupsFetchedCallbacks {
            apphudLog("Performing scheduled block..")
            block()
        }
        if productGroupsFetchedCallbacks.count > 0 {
            apphudLog("All scheduled blocks performed, removing..")
            productGroupsFetchedCallbacks.removeAll()
        }
    }

    // MARK: API Requests

    private func createOrGetUser(shouldUpdateUserID: Bool, callback: @escaping (Bool) -> Void) {

        let fields = shouldUpdateUserID ? ["user_id": self.currentUserID] : [:]

        self.updateUser(fields: fields) { (result, response, error, _) in

            let hasChanges = self.parseUser(response)

            let finalResult = result && self.currentUser != nil

            if finalResult {
                if hasChanges.hasSubscriptionChanges {
                    self.delegate?.apphudSubscriptionsUpdated?(self.currentUser!.subscriptions)
                }
                if hasChanges.hasNonRenewingChanges {
                    self.delegate?.apphudNonRenewingPurchasesUpdated?(self.currentUser!.purchases)
                }
                if UserDefaults.standard.bool(forKey: self.requiresReceiptSubmissionKey) {
                    self.submitReceiptRestore(allowsReceiptRefresh: false)
                }
            }

            if error != nil {
                apphudLog("Failed to register or get user, error:\(error!.localizedDescription)", forceDisplay: true)
            }

            callback(finalResult)
        }
    }

    private func updateUserCurrencyIfNeeded(priceLocale: Locale?) {
        guard let priceLocale = priceLocale else { return }
        guard let countryCode = priceLocale.regionCode else { return }
        guard let currencyCode = priceLocale.currencyCode else { return }

        if countryCode == self.currentUser?.countryCode && currencyCode == self.currentUser?.currencyCode {return}

        var params: [String: String] = ["country_code": countryCode,
                                          "currency_code": currencyCode]

        params.merge(apphudCurrentDeviceParameters()) { (current, _) in current}

        updateUser(fields: params) { (result, response, _, _) in
            if result {
                self.parseUser(response)
            }
        }
    }

    internal func updateUserID(userID: String) {

        guard self.currentUserID != userID else {
            apphudLog("Will not update User ID to \(userID), because current value is the same")
            return
        }

        let exist = performWhenUserRegistered {

            self.updateUser(fields: ["user_id": userID]) { (result, response, _, _) in
                if result {
                    self.parseUser(response)
                }
            }
        }
        if !exist {
            apphudLog("Tried to make update user id: \(userID) request when user is not yet registered, addind to schedule..")
        }
    }

    private func updateUser(fields: [String: Any], callback: @escaping ApphudHTTPResponseCallback) {
        var params = apphudCurrentDeviceParameters() as [String: Any]
        params.merge(fields) { (current, _) in current}
        params["device_id"] = self.currentDeviceID
        params["is_debug"] = apphudIsSandbox()
        // do not automatically pass currentUserID here,because we have separate method updateUserID
        httpClient.startRequest(path: "customers", params: params, method: .post, callback: callback)
    }

    private func refreshCurrentUser() {
        createOrGetUser(shouldUpdateUserID: false) { _ in
            self.lastCheckDate = Date()
        }
    }

    private func getProducts(callback: @escaping (([String: String]?) -> Void)) {

        httpClient.startRequest(path: "products", params: nil, method: .get) { (result, response, _, _) in
            if result, let dataDict = response?["data"] as? [String: Any],
                let productsArray = dataDict["results"] as? [[String: Any]] {

                var map = [String: String]()

                for product in productsArray {
                    let productID = product["product_id"] as! String
                    let groupID = (product["group_id"] as? String) ?? ""
                    map[productID] = groupID
                }
                callback(map)
            } else {
                callback(nil)
            }
        }
    }

    private func submitProducts(products: [SKProduct], callback: ApphudHTTPResponseCallback?) {
        var array = [[String: Any]]()
        for product in products {
            let productParams: [String: Any] = product.apphudSubmittableParameters()
            array.append(productParams)
        }

        let params = ["products": array] as [String: Any]

        httpClient.startRequest(path: "products", params: params, method: .put, callback: callback)
    }

    // MARK: - Main Purchase and Submit Receipt methods

    internal func restorePurchases(callback: @escaping ([ApphudSubscription]?, [ApphudNonRenewingPurchase]?, Error?) -> Void) {
        self.restorePurchasesCallback = callback
        self.submitReceiptRestore(allowsReceiptRefresh: true)
    }

    internal func submitReceiptAutomaticPurchaseTracking(transaction: SKPaymentTransaction) {

        if isSubmittingReceipt {return}

        performWhenUserRegistered {
            guard let receiptString = apphudReceiptDataString() else { return }
            self.submitReceipt(product: nil, transaction: transaction, receiptString: receiptString, notifyDelegate: true, callback: nil)
        }
    }

    internal func submitReceiptRestore(allowsReceiptRefresh: Bool) {
        guard let receiptString = apphudReceiptDataString() else {
            if allowsReceiptRefresh {
                apphudLog("App Store receipt is missing on device, will refresh first then retry")
                ApphudStoreKitWrapper.shared.refreshReceipt()
            } else {
                apphudLog("App Store receipt is missing on device and couldn't be refreshed.", forceDisplay: true)
                self.restorePurchasesCallback?(nil, nil, nil)
                self.restorePurchasesCallback = nil
            }
            return
        }

        let exist = performWhenUserRegistered {
            self.submitReceipt(product: nil, transaction: nil, receiptString: receiptString, notifyDelegate: true) { error in
                self.restorePurchasesCallback?(self.currentUser?.subscriptions, self.currentUser?.purchases, error)
                self.restorePurchasesCallback = nil
            }
        }
        if !exist {
            apphudLog("Tried to make restore allows: \(allowsReceiptRefresh) request when user is not yet registered, addind to schedule..")
        }
    }

    internal func submitReceipt(product: SKProduct, transaction: SKPaymentTransaction?, callback: ((ApphudPurchaseResult) -> Void)?) {
        guard let receiptString = apphudReceiptDataString() else {
            ApphudStoreKitWrapper.shared.refreshReceipt()
            callback?(ApphudPurchaseResult(nil, nil, nil, ApphudError(message: "Receipt not found on device, refreshing.")))
            return
        }

        let exist = performWhenUserRegistered {
            self.submitReceipt(product: product, transaction: transaction, receiptString: receiptString, notifyDelegate: true) { error in
                let result = self.purchaseResult(productId: product.productIdentifier, transaction: transaction, error: error)
                callback?(result)
            }
        }
        if !exist {
            apphudLog("Tried to make submitReceipt: \(product.productIdentifier) request when user is not yet registered, addind to schedule..")
        }
    }

    private func submitReceipt(product: SKProduct?, transaction: SKPaymentTransaction?, receiptString: String, notifyDelegate: Bool, callback: ((Error?) -> Void)?) {

        if callback != nil {
            self.submitReceiptCallback = callback
        }

        if isSubmittingReceipt {return}
        isSubmittingReceipt = true

        let environment = Apphud.isSandbox() ? "sandbox" : "production"

        var params: [String: Any] = ["device_id": self.currentDeviceID,
                                          "receipt_data": receiptString,
                                          "environment": environment]

        if let transactionID = transaction?.transactionIdentifier {
            params["transaction_id"] = transactionID
        }
        if let product = product {
            params["product_info"] = product.apphudSubmittableParameters()
        } else if let productID = transaction?.payment.productIdentifier, let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == productID}) {
            params["product_info"] = product.apphudSubmittableParameters()
        }

        UserDefaults.standard.set(true, forKey: requiresReceiptSubmissionKey)

        httpClient.startRequest(path: "subscriptions", params: params, method: .post) { (result, response, error, code) in

            self.forceSendAttributionDataIfNeeded()

            if code == 422 || code > 499 {
                // make one time retry
                self.httpClient.startRequest(path: "subscriptions", params: params, method: .post) { (result2, response2, error2, _) in
                    self.isSubmittingReceipt = false
                    self.handleSubmitReceiptCallback(result: result2, response: response2, error: error2, notifyDelegate: notifyDelegate)
                }
            } else {
                self.isSubmittingReceipt = false
                self.handleSubmitReceiptCallback(result: result, response: response, error: error, notifyDelegate: notifyDelegate)
            }
        }
    }

    internal func handleSubmitReceiptCallback(result: Bool, response: [String: Any]?, error: Error?, notifyDelegate: Bool) {

        if result {
            UserDefaults.standard.set(false, forKey: self.requiresReceiptSubmissionKey)
            UserDefaults.standard.synchronize()
            let hasChanges = self.parseUser(response)
            if notifyDelegate {
                if hasChanges.hasSubscriptionChanges {
                    self.delegate?.apphudSubscriptionsUpdated?(self.currentUser!.subscriptions)
                }
                if hasChanges.hasNonRenewingChanges {
                    self.delegate?.apphudNonRenewingPurchasesUpdated?(self.currentUser!.purchases)
                }
            }
        }

        self.submitReceiptCallback?(error)
        self.submitReceiptCallback = nil
    }

    internal func purchase(product: SKProduct, callback: ((ApphudPurchaseResult) -> Void)?) {
        ApphudStoreKitWrapper.shared.purchase(product: product) { transaction, error in
            self.handleTransaction(product: product, transaction: transaction, error: error) { (result) in
                callback?(result)
            }
        }
    }

    internal func purchaseWithoutValidation(product: SKProduct, callback: ApphudTransactionCallback?) {
        ApphudStoreKitWrapper.shared.purchase(product: product) { transaction, error in
            self.handleTransaction(product: product, transaction: transaction, error: error, callback: nil)
            callback?(transaction, error)
        }
    }

    @available(iOS 12.2, *)
    internal func purchasePromo(product: SKProduct, discountID: String, callback: ((ApphudPurchaseResult) -> Void)?) {
        self.signPromoOffer(productID: product.productIdentifier, discountID: discountID) { (paymentDiscount, _) in
            if let paymentDiscount = paymentDiscount {
                self.purchasePromo(product: product, discount: paymentDiscount, callback: callback)
            } else {
                callback?(ApphudPurchaseResult(nil, nil, nil, ApphudError(message: "Could not sign offer id: \(discountID), product id: \(product.productIdentifier)")))
            }
        }
    }

    @available(iOS 12.2, *)
    internal func purchasePromo(product: SKProduct, discount: SKPaymentDiscount, callback: ((ApphudPurchaseResult) -> Void)?) {
        ApphudStoreKitWrapper.shared.purchase(product: product, discount: discount) { transaction, error in
            self.handleTransaction(product: product, transaction: transaction, error: error, callback: callback)
        }
    }

    private func handleTransaction(product: SKProduct, transaction: SKPaymentTransaction, error: Error?, callback: ((ApphudPurchaseResult) -> Void)?) {
        if transaction.transactionState == .purchased {
            self.submitReceipt(product: product, transaction: transaction) { (result) in
                SKPaymentQueue.default().finishTransaction(transaction)
                callback?(result)
            }
        } else {
            callback?(purchaseResult(productId: product.productIdentifier, transaction: transaction, error: error))
            SKPaymentQueue.default().finishTransaction(transaction)
        }
    }

    private func purchaseResult(productId: String, transaction: SKPaymentTransaction?, error: Error?) -> ApphudPurchaseResult {

        // 1. try to find in app purchase by product id
        var purchase: ApphudNonRenewingPurchase?
        if transaction?.transactionState == .purchased {
            purchase = currentUser?.purchases.first(where: {$0.productId == productId})
        }

        // 1. try to find subscription by product id
        var subscription = currentUser?.subscriptions.first(where: {$0.productId == productId})
        // 2. try to find subscription by SKProduct's subscriptionGroupIdentifier
        if purchase == nil, subscription == nil, #available(iOS 12.2, *) {
            let targetProduct = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == productId})
            for sub in currentUser?.subscriptions ?? [] {
                if let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == sub.productId}),
                targetProduct?.subscriptionGroupIdentifier == product.subscriptionGroupIdentifier {
                    subscription = sub
                    break
                }
            }
        }

        // 3. Try to find subscription by groupID provided in Apphud project settings
        if subscription == nil, let groupID = self.productsGroupsMap?[productId] {
            subscription = currentUser?.subscriptions.first(where: { self.productsGroupsMap?[$0.productId] == groupID})
        }

        return ApphudPurchaseResult(subscription, purchase, transaction, error ?? transaction?.error)
    }

    @available(iOS 12.2, *)
    internal func signPromoOffer(productID: String, discountID: String, callback: ((SKPaymentDiscount?, Error?) -> Void)?) {
        let params: [String: Any] = ["product_id": productID, "offer_id": discountID ]
        httpClient.startRequest(path: "sign_offer", params: params, method: .post) { (result, dict, error, _) in
            if result, let responseDict = dict, let dataDict = responseDict["data"] as? [String: Any], let resultsDict = dataDict["results"] as? [String: Any] {

                let signatureData = resultsDict["data"] as? [String: Any]
                let uuid = UUID(uuidString: signatureData?["nonce"] as? String ?? "")
                let signature = signatureData?["signature"] as? String
                let timestamp = signatureData?["timestamp"] as? NSNumber
                let keyID = resultsDict["key_id"] as? String

                if signature != nil && uuid != nil && timestamp != nil && keyID != nil {
                    let paymentDiscount = SKPaymentDiscount(identifier: discountID, keyIdentifier: keyID!, nonce: uuid!, signature: signature!, timestamp: timestamp!)
                    callback?(paymentDiscount, nil)
                    return
                }
            }

            let error = ApphudError(message: "Could not sign promo offer id: \(discountID), product id: \(productID)")
            callback?(nil, error)
        }
    }

    // MARK: - Eligibilities API

    @available(iOS 12.2, *)
    internal func checkEligibilitiesForPromotionalOffers(products: [SKProduct], callback: @escaping ApphudEligibilityCallback) {

        let result = performWhenUserRegistered {

            apphudLog("User registered, check promo eligibility")

            let didSendReceiptForPromoEligibility = "ReceiptForPromoSent"

            // not found subscriptions, try to restore and try again
            if self.currentUser?.subscriptions.count ?? 0 == 0 && !UserDefaults.standard.bool(forKey: didSendReceiptForPromoEligibility) {
                if let receiptString = apphudReceiptDataString() {
                    apphudLog("Restoring subscriptions for promo eligibility check")
                    self.submitReceipt(product: nil, transaction: nil, receiptString: receiptString, notifyDelegate: true, callback: { _ in
                        UserDefaults.standard.set(true, forKey: didSendReceiptForPromoEligibility)
                        self._checkPromoEligibilitiesForRegisteredUser(products: products, callback: callback)
                    })
                } else {
                    apphudLog("Receipt not found for promo eligibility check, exiting")
                    // receipt not found and subscriptions not purchased, impossible to determine eligibility
                    // this should never not happen on production, because receipt always exists
                    var response = [String: Bool]()
                    for product in products {
                        response[product.productIdentifier] = false // cannot purchase offer by default
                    }
                    callback(response)
                }
            } else {
                apphudLog("Has purchased subscriptions or has checked receipt for promo eligibility")
                self._checkPromoEligibilitiesForRegisteredUser(products: products, callback: callback)
            }
        }
        if !result {
            apphudLog("Tried to check promo eligibility, but user not registered, adding to schedule")
        }
    }

    @available(iOS 12.2, *)
    private func _checkPromoEligibilitiesForRegisteredUser(products: [SKProduct], callback: @escaping ApphudEligibilityCallback) {

        var response = [String: Bool]()
        for product in products {
            response[product.productIdentifier] = false
        }

        let result = self.performWhenProductGroupsFetched {

            apphudLog("Products fetched, check promo eligibility")

            for subscription in self.currentUser?.subscriptions ?? [] {
                for product in products {
                    let purchasedGroupId = self.productsGroupsMap?[subscription.productId]
                    let givenGroupId = self.productsGroupsMap?[product.productIdentifier]
                    if (subscription.productId == product.productIdentifier) ||
                        (purchasedGroupId != nil && purchasedGroupId == givenGroupId) {
                        // if the same product or in the same group
                        response[product.productIdentifier] = true
                        // do not break, check all products
                    }
                }
            }
            apphudLog("Finished promo checking, response: \(response as AnyObject)")
            callback(response)
        }
        if !result {
            apphudLog("Tried to check promo eligibility, but products not fetched, adding to schedule")
        }
    }

    /// Checks introductory offers eligibility (includes free trial, pay as you go or pay up front)
    internal func checkEligibilitiesForIntroductoryOffers(products: [SKProduct], callback: @escaping ApphudEligibilityCallback) {

        let result = performWhenUserRegistered {

            apphudLog("User registered, check intro eligibility")

            // not found subscriptions, try to restore and try again

            let didSendReceiptForIntroEligibility = "ReceiptForIntroSent"

            if self.currentUser?.subscriptions.count ?? 0 == 0 && !UserDefaults.standard.bool(forKey: didSendReceiptForIntroEligibility) {
                if let receiptString = apphudReceiptDataString() {
                    apphudLog("Restoring subscriptions for intro eligibility check")
                    self.submitReceipt(product: nil, transaction: nil, receiptString: receiptString, notifyDelegate: true, callback: { _ in
                        UserDefaults.standard.set(true, forKey: didSendReceiptForIntroEligibility)
                        self._checkIntroEligibilitiesForRegisteredUser(products: products, callback: callback)
                    })
                } else {
                    apphudLog("Receipt not found for intro eligibility check, exiting")
                    // receipt not found and subscriptions not purchased, impossible to determine eligibility
                    // this should never not happen on production, because receipt always exists
                    var response = [String: Bool]()
                    for product in products {
                        response[product.productIdentifier] = true // can purchase intro by default
                    }
                    callback(response)
                }
            } else {
                apphudLog("Has purchased subscriptions or has checked receipt for intro eligibility")
                self._checkIntroEligibilitiesForRegisteredUser(products: products, callback: callback)
            }
        }
        if !result {
            apphudLog("Tried to check intro eligibility, but user not registered, adding to schedule")
        }
    }

    private func _checkIntroEligibilitiesForRegisteredUser(products: [SKProduct], callback: @escaping ApphudEligibilityCallback) {

        var response = [String: Bool]()
        for product in products {
            response[product.productIdentifier] = true
        }

        let result = self.performWhenProductGroupsFetched {

            apphudLog("Products fetched, check intro eligibility")

            for subscription in self.currentUser?.subscriptions ?? [] {
                for product in products {
                    let purchasedGroupId = self.productsGroupsMap?[subscription.productId]
                    let givenGroupId = self.productsGroupsMap?[product.productIdentifier]

                    if subscription.productId == product.productIdentifier ||
                        (purchasedGroupId == givenGroupId && givenGroupId != nil) {
                        // if purchased, then this subscription is eligible for intro only if not used intro and status expired
                        let eligible = !subscription.isIntroductoryActivated && subscription.status == .expired
                        response[product.productIdentifier] = eligible
                        // do not break, check all products
                    }
                }
            }
            apphudLog("Finished intro checking, response: \(response as AnyObject)")
            callback(response)
        }

        if !result {
            apphudLog("Tried to check intro eligibility, but products not fetched, adding to schedule")
        }
    }

    // MARK: - Push Notifications API

    internal func submitPushNotificationsToken(token: Data, callback: ApphudBoolCallback?) {
        performWhenUserRegistered {
            let tokenString = token.map { String(format: "%02.2hhx", $0) }.joined()
            let params: [String: String] = ["device_id": self.currentDeviceID, "push_token": tokenString]
            self.httpClient.startRequest(path: "customers/push_token", params: params, method: .put) { (result, _, _, _) in
                callback?(result)
            }
        }
    }

    // MARK: - V2 API

    internal func trackEvent(params: [String: AnyHashable], callback: @escaping () -> Void) {

        let result = performWhenUserRegistered {
            let final_params: [String: AnyHashable] = ["device_id": self.currentDeviceID].merging(params, uniquingKeysWith: {(current, _) in current})
            self.httpClient.startRequest(path: "events", apiVersion: .v2, params: final_params, method: .post) { (_, _, _, _) in
                callback()
            }
        }
        if !result {
            apphudLog("Tried to trackRuleEvent, but user not yet registered, adding to schedule")
        }
    }

    /// Not used yet
    internal func getRule(ruleID: String, callback: @escaping (ApphudRule?) -> Void) {

        let result = performWhenUserRegistered {
            let params = ["device_id": self.currentDeviceID] as [String: String]

            self.httpClient.startRequest(path: "rules/\(ruleID)", apiVersion: .v2, params: params, method: .get) { (result, response, _, _) in
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
        performWhenUserRegistered {
            let params = ["device_id": self.currentDeviceID] as [String: String]
            self.httpClient.startRequest(path: "notifications", apiVersion: .v2, params: params, method: .get, callback: { (result, response, _, _) in

                if result, let dataDict = response?["data"] as? [String: Any], let notifArray = dataDict["results"] as? [[String: Any]], let notifDict = notifArray.first, var ruleDict = notifDict["rule"] as? [String: Any] {
                    let properties = notifDict["properties"] as? [String: Any]
                    ruleDict = ruleDict.merging(properties ?? [:], uniquingKeysWith: {_, new in new})
                    let rule = ApphudRule(dictionary: ruleDict)
                    ApphudRulesManager.shared.handleRule(rule: rule)
                }
            })
        }
    }

    internal func readAllNotifications(for ruleID: String) {
        performWhenUserRegistered {
            let params = ["device_id": self.currentDeviceID, "rule_id": ruleID] as [String: String]
            self.httpClient.startRequest(path: "notifications/read", apiVersion: .v2, params: params, method: .post, callback: { (_, _, _, _) in
            })
        }
    }

    // MARK: - Attribution
    internal func addAttribution(data: [AnyHashable: Any]?, from provider: ApphudAttributionProvider, identifer: String? = nil, callback: ((Bool) -> Void)?) {
        performWhenUserRegistered {

            var params: [String: Any] = ["device_id": self.currentDeviceID]

            switch provider {
                case .appsFlyer:
                    guard identifer != nil else {
                        callback?(false)
                        return
                    }
                    guard !self.isSendingAppsFlyer else {
                        apphudLog("Already submitting AppsFlyer attribution, skipping", forceDisplay: true)
                        callback?(false)
                        return
                    }
                    params["appsflyer_id"] = identifer
                    if data != nil {
                        params["appsflyer_data"] = data
                    }
                    self.isSendingAppsFlyer = true
                case .adjust:
                    guard !self.isSendingAdjust else {
                        apphudLog("Already submitting Adjust attribution, skipping", forceDisplay: true)
                        callback?(false)
                        return
                    }
                    if data != nil {
                        params["adjust_data"] = data
                    }
                    self.isSendingAdjust = true
                case .appleSearchAds:
                    if data != nil {
                        params["search_ads_data"] = data
                    }
                case .facebook:
                    var hash: [AnyHashable: Any] = ["fb_device": true]

                    if apphudNeedsToCollectFBAnonID(), let anonID = apphudGetFBAnonID() {
                        hash["anon_id"] = anonID
                    }
                    if data != nil {
                        hash.merge(data!, uniquingKeysWith: {_, new in new})
                    }
                    params["facebook_data"] = hash
            }

            self.httpClient.startRequest(path: "customers/attribution", params: params, method: .post) { (result, _, _, _) in

                switch provider {
                    case .adjust:
                        UserDefaults.standard.set((result ? nil : data), forKey: "adjust_data_cache")
                        DispatchQueue.main.asyncAfter(deadline: .now()+1.0) {
                            self.isSendingAdjust = false
                        }
                        if result {
                            self.didSubmitAdjustAttribution = true
                        }
                    case .appsFlyer:
                        DispatchQueue.main.asyncAfter(deadline: .now()+5.0) {
                            self.isSendingAppsFlyer = false
                        }
                        if result {
                            self.didSubmitAppsFlyerAttribution = true
                        }
                    case .facebook:
                        if result {
                            self.didSubmitFacebookAttribution = true
                        }
                    default:
                        break
                }

                callback?(result)
            }
        }
    }

    @objc internal func forceSendAttributionDataIfNeeded() {
        automaticallySubmitAppsFlyerAttributionIfNeeded()
        automaticallySubmitAdjustAttributionIfNeeded()
        automaticallySubmitFacebookAttributionIfNeeded()
    }

    @objc internal func automaticallySubmitAppsFlyerAttributionIfNeeded() {

        guard !didSubmitAppsFlyerAttribution && apphudIsAppsFlyerSDKIntegrated() else {
            return
        }

        if let appsFlyerID = apphudGetAppsFlyerID() {
            apphudLog("AppsFlyer SDK is integrated, but attribution still not submitted. Will force submit", forceDisplay: true)
            addAttribution(data: nil, from: .appsFlyer, identifer: appsFlyerID, callback: nil)
        } else {
            apphudLog("Couldn't automatically resubmit AppsFlyer attribution, exiting.", forceDisplay: true)
        }
    }

    @objc internal func automaticallySubmitAdjustAttributionIfNeeded() {

        guard !didSubmitAdjustAttribution && apphudIsAdjustSDKIntegrated() else {
            return
        }

        apphudLog("Adjust SDK is integrated, but attribution still not submitted. Will force submit", forceDisplay: true)

        var data: [AnyHashable: Any]?
        if let cached_data = UserDefaults.standard.object(forKey: "adjust_data_cache") as? [AnyHashable: Any] {
            data = cached_data
        } else if let adid = apphudGetAdjustID() {
            data = ["adid": adid]
        }

        if data != nil {
            addAttribution(data: data!, from: .adjust, callback: { result in
                if !result {
                    self.perform(#selector(self.automaticallySubmitAdjustAttributionIfNeeded), with: nil, afterDelay: 7.0)
                    apphudLog("Adjust attribution still not submitted, will retry in 7 seconds")
                }
            })
        } else {
            apphudLog("Couldn't automatically resubmit Adjust attribution, exiting.", forceDisplay: true)
        }
    }

    @objc internal func automaticallySubmitFacebookAttributionIfNeeded() {
        guard !didSubmitFacebookAttribution && apphudIsFBSDKIntegrated() else {
            return
        }

        addAttribution(data: [:], from: .facebook, callback: nil)
    }
}
