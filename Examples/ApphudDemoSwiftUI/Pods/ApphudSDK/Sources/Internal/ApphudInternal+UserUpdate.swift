//
//  ApphudInternal+Registration.swift
//  apphud
//
//  Created by Renat on 01.07.2020.
//  Copyright © 2020 Apphud Inc. All rights reserved.
//

import Foundation
import StoreKit

extension ApphudInternal {
    @discardableResult internal func parseUser(data: Data?) async -> HasPurchasesChanges {

        guard let data = data else {
            return (false, false)
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        let oldStates = await currentUser?.subscriptionsStates()
        let oldPurchasesStates = await currentUser?.purchasesStates()

        do {
            let response = try decoder.decode(ApphudUserResponse<ApphudUser>.self, from: data)
            await MainActor.run {
                currentUser = response.data.results
            }
        } catch {
            apphudLog("Failed to decode ApphudUser, error: \(error)")
        }

        if let pwls = await currentUser?.paywalls {
            await preparePaywalls(pwls: pwls, writeToCache: true, completionBlock: nil)
        } else {
            didPreparePaywalls = true
        }

        let newStates = await currentUser?.subscriptionsStates()
        let newPurchasesStates = await currentUser?.purchasesStates()

        await currentUser?.toCacheV2()

        Task { @MainActor in
            checkUserID(tellDelegate: true)
        }

        /**
         If user previously didn't have subscriptions or subscriptions states don't match, or subscription product identifiers don't match
         */
        let currentSubs = await currentUser?.subscriptions
        let currentPurchs = await currentUser?.purchases

        let hasSubscriptionChanges = (oldStates != newStates && currentSubs != nil)
        let hasPurchasesChanges = (oldPurchasesStates != newPurchasesStates && currentPurchs != nil)
        return (hasSubscriptionChanges, hasPurchasesChanges)
    }
    
    func updatePremiumStatus(user: ApphudUser?) {
        let hasActiveSub = user?.subscriptions.first(where: { $0.isActive() }) != nil
        let hasActivePurch = user?.purchases.first(where: { $0.isActive() }) != nil
        
        let premium = hasActiveSub || hasActivePurch
        
        isPremium = premium
        hasActiveSubscription = hasActiveSub
    }

    @MainActor private func checkUserID(tellDelegate: Bool) {
        guard let userID = self.currentUser?.userId else {return}
        if self.currentUserID != userID {
            self.currentUserID = userID
            ApphudKeychain.saveUserID(userID: self.currentUserID)
            if tellDelegate {
                self.delegate?.apphudDidChangeUserID(userID)
            }
        }
    }

    @MainActor
    internal func createOrGetUser(initialCall: Bool, skipRegistration: Bool = false, delay: Double = 0) async -> (Bool, Int) {
        if skipRegistration {
            apphudLog("Loading user from cache, because cache is not expired.")
            preparePaywalls(pwls: self.paywalls, writeToCache: false, completionBlock: nil)
            if self.requiresReceiptSubmission {
                self.submitAppStoreReceipt()
            }
            return (self.currentUser != nil, 0)
        }

        let fields = initialCall ? ["user_id": self.currentUserID, "initial_call": true] : [:]

        return await withUnsafeContinuation { continuation in
            updateUser(fields: fields, delay: delay) { (result, _, data, error, code, duration, attempts) in

                Task {
                    let hasChanges = await self.parseUser(data: data)

                    let finalResult = result && self.currentUser != nil

                    if finalResult {
                        ApphudLoggerService.lastUserUpdatedAt = Date()

                        if initialCall {
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

                    continuation.resume(returning: (finalResult, code))
                }
            }
        }
    }

    @MainActor
    internal func updateUserID(userID: String) {
        performWhenUserRegistered {

            guard self.currentUserID != userID else {
                apphudLog("Will not update User ID to \(userID), because current value is the same")
                return
            }

            self.updateUser(fields: ["user_id": userID]) { (result, _, data, _, _, _, attempts) in
                if result {
                    Task {
                        await self.parseUser(data: data)
                    }
                }
            }
        }
    }

    internal func grantPromotional(_ duration: Int, _ permissionGroup: ApphudGroup?, productId: String?, callback: ApphudBoolCallback?) {
        performWhenUserRegistered {
            self.grantPromotional(duration, permissionGroup, productId: productId) { (result, _, data, _, _, _, _) in
                if result {
                    Task {
                        let hasChanges = await self.parseUser(data: data)
                        self.notifyAboutUpdates(hasChanges)
                    }
                }
                callback?(result)
            }
        }
    }

    @MainActor private func grantPromotional(_ duration: Int, _ permissionGroup: ApphudGroup?, productId: String?, callback: @escaping ApphudHTTPResponseCallback) {
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

    @MainActor
    internal func updateUser(fields: [String: Any], delay: Double = 0, callback: @escaping ApphudHTTPResponseCallback) {

        //  Requires @MainActor since it collects data from UIDevice
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
        params["need_paywalls"] = !didPreparePaywalls && !deferPlacements
        params["need_placements"] = !didPreparePaywalls && !deferPlacements
        params["opt_out"] = ApphudUtils.shared.optOutOfTracking

        if params["user_id"] == nil, let userId = currentUser?.userId {
            params["user_id"] = userId
        }

        if let currency = storefrontCurrency, (currentUser?.currency?.countryCode != currency.countryCode || currentUser?.currency?.countryCodeAlpha3 != currency.countryCodeAlpha3) {

            if currency.countryCodeAlpha3 != nil {
                params["store_id"] = currency.storeId
                params["country_code_alpha3"] = currency.countryCodeAlpha3
            } else {
                params["country_code"] = currency.countryCode
                params["currency_code"] = currency.code
            }
        }

        // retry on http level only if setNeedsToUpdateUser = true, otherwise let retry on initial launch level
        let initialCall = params["initial_call"] != nil
        setNeedsToUpdateUser = false

        appInstallationDate.map { params["first_seen"] = $0 }
        Bundle.main.bundleIdentifier.map { params["bundle_id"] = $0 }
        // do not automatically pass currentUserID here,because we have separate method updateUserID

        DispatchQueue.main.asyncAfter(deadline: .now() + delay) { [self] in
            httpClient?.startRequest(path: .customers, params: params, method: .post, useDecoder: true, retry: !initialCall, requestID: initialCall ? initialRequestID : nil) { done, response, data, error, errorCode, duration, attempts in
                if  errorCode == 403 {
                    apphudLog("Unable to perform API requests, because your account has been suspended.", forceDisplay: true)
                    ApphudHttpClient.shared.unauthorized = true
                    ApphudHttpClient.shared.suspended = true
                }
                if  errorCode == 401 {
                    apphudLog("Unable to perform API requests, because your API Key is invalid.", forceDisplay: true)
                    ApphudHttpClient.shared.invalidAPiKey = true
                }
                callback(done, response, data, error, errorCode, duration, attempts)
            }
        }
    }

    @objc internal func updateCurrentUser() {
        refreshCurrentUser {}
    }
    
    @objc internal func refreshCurrentUser(completion: @escaping () -> Void) {
        Task.detached(priority: .userInitiated) {
            _ = await self.createOrGetUser(initialCall: false)
            completion()
        }
    }

    @MainActor
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
        
        Task { @MainActor in
            let property = ApphudUserProperty(key: key.key, value: value, increment: increment, setOnce: setOnce, type: typeString)
            await ApphudDataActor.shared.addPendingUserProperty(property)
        }

        performWhenUserRegistered {
            Task { @MainActor in
                self.setNeedsToUpdateUserProperties = true
            }
        }
    }

    @objc internal func updateUserProperties() {
        flushUserProperties(force: false, completion: nil)
    }
    
    internal func flushUserProperties(force: Bool, completion: ((Bool) -> Void)? = nil) {
        Task {
            let values = await self.preparePropertiesParams(isAudience: force)
            guard let params = values.0, let properties = values.1 else {
                completion?(false)
                return
            }

            let canSaveToCache = values.2

            httpClient?.startRequest(path: .properties, params: params, method: .post, retry: true) { (result, _, _, error, code, _, _) in
                if result {
                    if canSaveToCache {
                        Task {
                            await ApphudDataActor.shared.setUserPropertiesCache(properties)
                        }
                    }
                    apphudLog("User Properties successfully updated.")
                } else {
                    apphudLog("User Properties update failed: \(error?.localizedDescription ?? "") with code: \(code)")
                }
                
                completion?(result)
            }
        }
    }

    private func preparePropertiesParams(isAudience:Bool = false) async -> ([String: Any]?, [[String: Any?]]?, Bool) {
        setNeedsToUpdateUserProperties = false
        guard await ApphudDataActor.shared.pendingUserProps.count > 0 else { return (nil, nil, false) }
        var params = [String: Any]()
        params["device_id"] = self.currentDeviceID
        params["force"] = isAudience

        var canSaveToCache = true
        var properties = [[String: Any?]]()
        await ApphudDataActor.shared.pendingUserProps.forEach { property in
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
            await ApphudDataActor.shared.setUserPropertiesCache(nil)
        } else if let cachedProperties = await ApphudDataActor.shared.userPropertiesCache {
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
                await ApphudDataActor.shared.setPendingUserProperties([])
                return (nil, nil, false)
            }
        }

        await ApphudDataActor.shared.setPendingUserProperties([])

        return (params, properties, canSaveToCache)
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
