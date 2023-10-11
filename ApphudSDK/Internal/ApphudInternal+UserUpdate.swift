//
//  ApphudInternal+Registration.swift
//  apphud
//
//  Created by Renat on 01.07.2020.
//  Copyright © 2020 Apphud Inc. All rights reserved.
//

import Foundation
#if canImport(UIKit)
import UIKit
#endif

extension ApphudInternal {

    @discardableResult internal func parseUser(data: Data?) -> HasPurchasesChanges {

        guard let data = data else {
            return (false, false)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let oldStates = currentUser?.subscriptionsStates()
        let oldPurchasesStates = currentUser?.purchasesStates()

        do {
            let response = try decoder.decode(ApphudUserResponse<ApphudUser>.self, from: data)
            currentUser = response.data.results
        } catch {
            apphudLog("Failed to decode ApphudUser, error: \(error)")
        }

        if let pwls = currentUser?.paywalls {
            self.preparePaywalls(pwls: pwls, writeToCache: true, completionBlock: nil)
        } else {
            didPreparePaywalls = true
        }

        let newStates = currentUser?.subscriptionsStates()
        let newPurchasesStates = currentUser?.purchasesStates()

        currentUser?.toCacheV2()

        checkUserID(tellDelegate: true)

        /**
         If user previously didn't have subscriptions or subscriptions states don't match, or subscription product identifiers don't match
         */
        let hasSubscriptionChanges = (oldStates != newStates && self.currentUser?.subscriptions != nil)
        let hasPurchasesChanges = (oldPurchasesStates != newPurchasesStates && self.currentUser?.purchases != nil)
        return (hasSubscriptionChanges, hasPurchasesChanges)
    }

    private func checkUserID(tellDelegate: Bool) {
        guard let userID = self.currentUser?.userId else {return}
        if self.currentUserID != userID {
            self.currentUserID = userID
            ApphudKeychain.saveUserID(userID: self.currentUserID)
            if tellDelegate {
                self.delegate?.apphudDidChangeUserID(userID)
            }
        }
    }

    internal func createOrGetUser(shouldUpdateUserID: Bool, skipRegistration: Bool = false, delay: Double = 0, callback: @escaping (Bool, Int) -> Void) {
        if skipRegistration {
            apphudLog("Loading user from cache, because cache is not expired.")
            self.preparePaywalls(pwls: self.paywalls, writeToCache: false, completionBlock: nil)
            if self.requiresReceiptSubmission {
                self.submitAppStoreReceipt()
            }
            callback(true, 0)
            return
        }

        let needLogging = shouldUpdateUserID
        let fields = shouldUpdateUserID ? ["user_id": self.currentUserID] : [:]

        self.updateUser(fields: fields, delay: delay) { (result, response, data, error, code, duration) in

            let hasChanges = self.parseUser(data: data)

            let finalResult = result && self.currentUser != nil

            if finalResult {
                ApphudLoggerService.lastUserUpdatedAt = Date()

                if needLogging {
                    ApphudLoggerService.shared.add(key: .customers, value: duration, retryLog: self.userRegisterRetries)
                }

                self.notifyAboutUpdates(hasChanges)

                if self.requiresReceiptSubmission {
                    self.submitAppStoreReceipt()
                }
            }

            if error != nil {
                apphudLog("Failed to register or get user, error:\(error!.localizedDescription)", forceDisplay: true)
            }

            callback(finalResult, code)
        }
    }

    internal func updateUserCurrencyIfNeeded(priceLocale: Locale?) {
        guard let priceLocale = priceLocale else { return }
        guard let countryCode = priceLocale.regionCode else { return }
        guard let currencyCode = priceLocale.currencyCode else { return }
        guard self.currentUser != nil else { return }

        if countryCode == self.currentUser?.currency?.countryCode && currencyCode == self.currentUser?.currency?.code {return}

        let params: [String: String] = ["country_code": countryCode, "currency_code": currencyCode]

        updateUser(fields: params, delay: 2.0) { (result, _, data, _, _, _) in
            if result {
                self.parseUser(data: data)
            }
        }
    }

    internal func updateUserID(userID: String) {

        guard self.currentUserID != userID else {
            apphudLog("Will not update User ID to \(userID), because current value is the same")
            return
        }

        let exist = performWhenUserRegistered {

            self.updateUser(fields: ["user_id": userID]) { (result, _, data, _, _, _) in
                if result {
                    self.parseUser(data: data)
                }
            }
        }
        if !exist {
            apphudLog("Tried to make update user id: \(userID) request when user is not yet registered, addind to schedule..")
        }
    }

    internal func grantPromotional(_ duration: Int, _ permissionGroup: ApphudGroup?, productId: String?, callback: ApphudBoolCallback?) {
        performWhenUserRegistered {
            self.grantPromotional(duration, permissionGroup, productId: productId) { (result, _, data, _, _, _) in
                if result {
                    let hasChanges = self.parseUser(data: data)
                    self.notifyAboutUpdates(hasChanges)
                }
                callback?(result)
            }
        }
    }

    private func grantPromotional(_ duration: Int, _ permissionGroup: ApphudGroup?, productId: String?, callback: @escaping ApphudHTTPResponseCallback) {
        var params: [String: Any] = [:]
        params["duration"] = duration
        params["user_id"] = currentUserID
        params["device_id"] = currentDeviceID

        if let productId = productId {
            params["product_id"] = productId
        } else if let permissionGroup = permissionGroup {
            params["product_group_id"] = permissionGroup.id
        }

        httpClient?.startRequest(path: .promotions, params: params, method: .post, callback: callback)
    }

    private func updateUser(fields: [String: Any], delay: Double = 0, callback: @escaping ApphudHTTPResponseCallback) {
        setNeedsToUpdateUser = false

        #if os(macOS)
        var params = apphudCurrentDeviceMacParameters() as [String: Any]
        #elseif os(watchOS)
        var params = apphudCurrentDeviceWatchParameters() as [String: Any]
        #else
        var params = apphudCurrentDeviceiOSParameters() as [String: Any]
        #endif

        if isRedownload && !reinstallTracked {
           params["reinstall"] = true
           reinstallTracked = true
        }

        params.merge(fields) { (current, _) in current}
        params["device_id"] = self.currentDeviceID
        params["is_debug"] = apphudIsSandbox()
        params["is_new"] = isFreshInstall && currentUser == nil
        params["need_paywalls"] = !didPreparePaywalls
        params["opt_out"] = ApphudUtils.shared.optOutOfTracking
        appInstallationDate.map { params["first_seen"] = $0 }
        Bundle.main.bundleIdentifier.map { params["bundle_id"] = $0 }
        // do not automatically pass currentUserID here,because we have separate method updateUserID

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
            httpClient?.startRequest(path: .customers, params: params, method: .post, useDecoder: true) { done, response, data, error, errorCode, duration in
                if  errorCode == 403 {
                    apphudLog("Unable to perform API requests, because your account has been suspended.", forceDisplay: true)
                    ApphudHttpClient.shared.unauthorized = true
                    ApphudHttpClient.shared.suspended = true
                }
                if  errorCode == 401 {
                    apphudLog("Unable to perform API requests, because your API Key is invalid.", forceDisplay: true)
                    ApphudHttpClient.shared.invalidAPiKey = true
                }
                callback(done, response, data, error, errorCode, duration)
            }
        }
    }

    @objc internal func updateCurrentUser() {
        createOrGetUser(shouldUpdateUserID: false) { _, _ in
            self.lastCheckDate = Date()
        }
    }

    func notifyAboutUpdates(_ hasChanges: HasPurchasesChanges) {
        if hasChanges.hasSubscriptionChanges {
            self.delegate?.apphudSubscriptionsUpdated(self.currentUser!.subscriptions)
        }
        if hasChanges.hasNonRenewingChanges {
            self.delegate?.apphudNonRenewingPurchasesUpdated(self.currentUser!.purchases)
        }
        if hasChanges.hasSubscriptionChanges || hasChanges.hasNonRenewingChanges {
            NotificationCenter.default.post(name: Apphud.didUpdateNotification(), object: nil)
        }
    }

    // MARK: - User Properties

    private func getType(value: Any?) -> String? {
        var type: String?

        if value == nil || value is NSNull {
            return "nil"
        } else if value is String || value is NSString {
            type = "string"
        } else if let number = value as? NSNumber {
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                type = "boolean"
            } else if CFNumberIsFloatType(number) {
                type = "float"
            }
        }
        if type == nil {
            if value is Int {
                type = "integer"
            } else if value is Float || value is Double {
                type = "float"
            } else if value is Bool {
                type = "boolean"
            }
        }
        return type
    }

    private func arePropertyValuesEqual(value1: Any?, value2: Any?) -> Bool {
        let className1 = object_getClass(value1)?.description() ?? ""
        let className2 = object_getClass(value2)?.description() ?? ""

        if className1 == "NSNull" && className2 == "NSNull" { return true }
        if value1 is NSNull && value2 is NSNull { return true }
        if value1 is String && value2 is String, value1 as? String == value2 as? String { return true }
        if value1 is NSString && value2 is NSString, (value1 as! NSString).isEqual(value2 as! NSString) { return true }
        if value1 is NSNumber && value2 is NSNumber, (value1 as! NSNumber).isEqual(value2 as! NSNumber) { return true }
        if value1 is Int && value2 is Int, value1 as! Int == value2 as! Int { return true }
        if value1 is Float && value2 is Float, value1 as! Float == value2 as! Float { return true }
        if value1 is Double && value2 is Double, value1 as! Double == value2 as! Double { return true }
        if value1 is Bool && value2 is Bool, value1 as! Bool == value2 as! Bool { return true }

        return false
    }

    internal func setUserProperty(key: ApphudUserPropertyKey, value: Any?, setOnce: Bool, increment: Bool = false) {

        guard let typeString = getType(value: value) else {
            let givenType = type(of: value)
            apphudLog("Invalid property type: (\(givenType)). Must be one of: [Int, Float, Double, Bool, String, NSNull, nil]", forceDisplay: true)
            return
        }

        if increment && !(typeString == "integer" || typeString == "float") {
            let givenType = type(of: value)
            apphudLog("Invalid increment property type: (\(givenType)). Must be one of: [Int, Float, Double]", forceDisplay: true)
            return
        }

        performWhenUserRegistered {
            let property = ApphudUserProperty(key: key.key, value: value, increment: increment, setOnce: setOnce, type: typeString)
            self.pendingUserProperties.removeAll { prop -> Bool in property.key == prop.key }
            self.pendingUserProperties.append(property)
            self.setNeedsToUpdateUserProperties = true
        }
    }

    @objc internal func updateUserProperties() {
        setNeedsToUpdateUserProperties = false
        guard pendingUserProperties.count > 0 else {return}
        var params = [String: Any]()
        params["device_id"] = self.currentDeviceID

        var canSaveToCache = true
        var properties = [[String: Any?]]()
        pendingUserProperties.forEach { property in
            if let json = property.toJSON() {
                properties.append(json)
                if property.increment {
                    canSaveToCache = false
                }
            }
        }
        params["properties"] = properties

        if canSaveToCache == false {
            // if new properties are not cacheable, then remove old cache and send new props to backend and not cache them
            self.userPropertiesCache = nil
        } else if let cachedProperties = self.userPropertiesCache {
            var shouldSkipUpload = true
            if cachedProperties.count == properties.count {
                for cachedProp in cachedProperties {
                    if let newProperty = properties.first(where: { $0["name"] as! String == cachedProp["name"] as! String }) {
                        if !arePropertyValuesEqual(value1: newProperty["value"] as Any?, value2: cachedProp["value"] as Any?) {
                            shouldSkipUpload = false
                            // values are not equal
                            break
                        }
                    } else {
                        // not found a property
                        shouldSkipUpload = false
                        break
                    }

                }
            } else {
                shouldSkipUpload = false
            }

            if shouldSkipUpload {
                apphudLog("Skip uploading user properties, because values did not change") //: \n\n\(properties),\n\ncache:\n\n\(cachedProperties)")
                self.pendingUserProperties.removeAll()
                return
            }
        }

        httpClient?.startRequest(path: .properties, params: params, method: .post) { (result, _, _, error, code, _) in
            if result {
                if canSaveToCache { self.userPropertiesCache = properties }
                self.pendingUserProperties.removeAll()
                apphudLog("User Properties successfully updated.")
            } else {
                apphudLog("User Properties update failed: \(error?.localizedDescription ?? "") with code: \(code)")
            }
        }
    }

    private var userPropertiesCache: [[String: Any?]]? {
        get {
            let cache = apphudDataFromCache(key: "ApphudUserPropertiesCache", cacheTimeout: 86_400*7)
            if let data = cache.objectsData, !cache.expired,
                let object = try? JSONSerialization.jsonObject(with: data, options: []) as? [[String: Any?]] {
                return object
            } else {
                return nil
            }
        }
        set {
            if newValue != nil, let data = try? JSONSerialization.data(withJSONObject: newValue!, options: .prettyPrinted) {
                apphudDataToCache(data: data, key: "ApphudUserPropertiesCache")
            }
        }
    }
}

extension ApphudInternal {
    var appInstallationDate: Int? {
        guard let documentsURL = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask).last,
              let attributes = try? FileManager.default.attributesOfItem(atPath: documentsURL.path)
        else { return nil }

        let dateFormatter = DateFormatter()
        dateFormatter.dateStyle = .medium
        dateFormatter.timeStyle = .medium
        dateFormatter.locale = Locale.current
        if let date = attributes[.creationDate] as? Date {
            return Int(date.timeIntervalSince1970)
        }
        return nil
    }

}
