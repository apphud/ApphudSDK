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

@available(OSX 10.14.4, *)
extension ApphudInternal {

    
    @discardableResult internal func parseUser(_ dict: [String: Any]?) -> PurchasesChanges {

        guard let dataDict = dict?["data"] as? [String: Any] else {
            return (false, false, [], [])
        }
        guard let userDict = dataDict["results"] as? [String: Any] else {
            return (false, false, [], [])
        }
        
        if let paywalls = userDict["paywalls"] as? [[String: Any]] {
            self.mappingPaywalls(paywalls)
        }

        let oldStates = self.currentUser?.subscriptionsStates()
        let oldPurchasesStates = self.currentUser?.purchasesStates()
        
        let oldSubscriptions = self.currentUser?.subscriptions
        let oldPurchases = self.currentUser?.purchases

        self.currentUser = ApphudUser(dictionary: userDict)
        
        let newSubscriptions = self.currentUser?.subscriptions
        let newPurchases = self.currentUser?.purchases

        let newStates = self.currentUser?.subscriptionsStates()
        let newPurchasesStates = self.currentUser?.purchasesStates()

        ApphudUser.toCache(userDict)

        checkUserID(tellDelegate: true)

        /**
         If user previously didn't have subscriptions or subscriptions states don't match, or subscription product identifiers don't match
         */
        
        let changedSubscriptions = newSubscriptions!.filter({ item in !oldSubscriptions!.contains(where: { $0.id == item.id }) })
        let changedPurchases = newPurchases!.filter({ item in !oldPurchases!.contains(where: { $0.productId == item.productId && $0.purchasedAt == item.purchasedAt  }) })
    
        let hasSubscriptionChanges = (oldStates != newStates && self.currentUser?.subscriptions != nil)
        let hasPurchasesChanges = (oldPurchasesStates != newPurchasesStates && self.currentUser?.purchases != nil)

        return (hasSubscriptionChanges, hasPurchasesChanges, changedSubscriptions, changedPurchases)
    }
        
    private func mappingPaywalls(_ pwls: [[String: Any]]) {
        let finalPaywalls = pwls.map { ApphudPaywall(dictionary: $0) }
        self.preparePaywalls(pwls: finalPaywalls, writeToCache: true, completionBlock: nil)
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

    internal func createOrGetUser(shouldUpdateUserID: Bool, skipRegistration:Bool = false, callback: @escaping (Bool, Int) -> Void) {
        if skipRegistration {
            apphudLog("Loading user from cache, because cache is not expired.")
            self.preparePaywalls(pwls: self.paywalls, writeToCache: false, completionBlock: nil)
            if self.requiresReceiptSubmission {
                self.submitAppStoreReceipt()
            }
            callback(true, 0)
            return
        }
        
        let fields = shouldUpdateUserID ? ["user_id": self.currentUserID] : [:]
        let startBench = Date()
        
        self.updateUser(fields: fields) { (result, response, _, error, code) in
            let hasChanges = self.parseUser(response)
            
            let finalResult = result && self.currentUser != nil
            
            if finalResult {
                ApphudLoggerService.lastUserUpdatedAt = Date()
                let endBench = startBench.timeIntervalSinceNow * -1
                ApphudLoggerService.shared.addDurationEvent(ApphudLoggerService.durationLog.customers.value(), endBench)
                
                if hasChanges.hasSubscriptionChanges {
                    self.delegate?.apphudSubscriptionsUpdated?(self.currentUser!.subscriptions)
                }
                if hasChanges.hasNonRenewingChanges {
                    self.delegate?.apphudNonRenewingPurchasesUpdated?(self.currentUser!.purchases)
                }
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

        if countryCode == self.currentUser?.countryCode && currencyCode == self.currentUser?.currencyCode {return}

        let params: [String: String] = ["country_code": countryCode, "currency_code": currencyCode]

        updateUser(fields: params) { (result, response, _, _, code) in
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

            self.updateUser(fields: ["user_id": userID]) { (result, response, _, _, code) in
                if result {
                    self.parseUser(response)
                }
            }
        }
        if !exist {
            apphudLog("Tried to make update user id: \(userID) request when user is not yet registered, addind to schedule..")
        }
    }
    
    internal func grantPromotional(_ duration: Int, _ permissionGroup:ApphudGroup?, productId:String?, callback: ApphudBoolCallback?) {
        performWhenUserRegistered {
            self.grantPromotional(duration, permissionGroup, productId: productId) { (result, response, _, _, _) in
                if result {
                    self.parseUser(response)
                }
                callback?(result)
            }
        }
    }
        
    private func grantPromotional(_ duration: Int, _ permissionGroup:ApphudGroup?, productId:String?, callback: @escaping ApphudHTTPResponseCallback) {
        var params: [String: Any] = [:]
        params["duration"] = duration
        params["user_id"] = currentUserID
        params["device_id"] = currentDeviceID
        
        if let productId = productId {
            params["product_id"] = productId
        } else if let permissionGroup = permissionGroup {
            params["product_group_id"] = permissionGroup.id
        }
        
        httpClient?.startRequest(path: "promotions", params: params, method: .post, callback: callback)
    }

    private func updateUser(fields: [String: Any], callback: @escaping ApphudHTTPResponseCallback) {
        setNeedsToUpdateUser = false
        var params = apphudCurrentDeviceParameters() as [String: Any]
        params.merge(fields) { (current, _) in current}
        params["device_id"] = self.currentDeviceID
        params["is_debug"] = apphudIsSandbox()
        params["is_new"] = isFreshInstall
        params["need_paywalls"] = !didRetrievePaywallsAtThisLaunch
        // do not automatically pass currentUserID here,because we have separate method updateUserID
        httpClient?.startRequest(path: "customers", params: params, method: .post, callback: callback)
    }

    @objc internal func updateCurrentUser() {
        createOrGetUser(shouldUpdateUserID: false) { _, _ in
            self.lastCheckDate = Date()
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
                apphudLog("Skip uploading user properties, because values did not change") //:\n\n\(properties),\n\ncache:\n\n\(cachedProperties)")
                self.pendingUserProperties.removeAll()
                return
            }
        }
        
        httpClient?.startRequest(path: "customers/properties", params: params, method: .post) { (result, _, _, error, code) in
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
            if let data = apphudDataFromCache(key: "ApphudUserPropertiesCache", cacheTimeout: 86_400*7),
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
