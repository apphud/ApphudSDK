//
//  ApphudInternal+Registration.swift
//  apphud
//
//  Created by Renat on 01.07.2020.
//  Copyright © 2020 Apphud Inc. All rights reserved.
//

import Foundation
import UIKit

extension ApphudInternal {

    @discardableResult internal func parseUser(_ dict: [String: Any]?) -> HasPurchasesChanges {

        guard let dataDict = dict?["data"] as? [String: Any] else {
            return (false, false)
        }
        guard let userDict = dataDict["results"] as? [String: Any] else {
            return (false, false)
        }
        
        if let paywalls = userDict["paywalls"] as? [[String: Any]] {
            self.mappingPaywalls(paywalls)
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
        
    private func mappingPaywalls(_ pwls: [[String: Any]]) {
        let finalPaywalls = pwls.map { ApphudPaywall(dictionary: $0) }
        self.preparePaywalls(pwls: finalPaywalls, writeToCache: finalPaywalls.count > 0, completionBlock: nil)
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

    internal func createOrGetUser(shouldUpdateUserID: Bool, callback: @escaping (Bool, Int) -> Void) {
        let fields = shouldUpdateUserID ? ["user_id": self.currentUserID] : [:]
        let startBench = Date()
        
        self.updateUser(fields: fields) { (result, response, _, error, code) in
            let hasChanges = self.parseUser(response)

            let finalResult = result && self.currentUser != nil

            if finalResult {
                let endBench = startBench.timeIntervalSinceNow * -1
                ApphudInternal.shared.logEvent(params: ["message": String(format:"customers_benchmark:%.3f", endBench)]) {}
                
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
                callback!(result)
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

    internal func setUserProperty(key: ApphudUserPropertyKey, value: Any?, setOnce: Bool, increment: Bool = false) {

        guard let typeString = getType(value: value) else {
            let givenType = type(of: value)
            apphudLog("Invalid property type: (\(givenType)). Must be one of: [Int, Float, Double, Bool, String, NSNull, nil]", forceDisplay: true)
            ApphudLoggerService.logError("set user property: Invalid property type")
            return
        }

        if increment && !(typeString == "integer" || typeString == "float") {
            let givenType = type(of: value)
            apphudLog("Invalid increment property type: (\(givenType)). Must be one of: [Int, Float, Double]", forceDisplay: true)
            ApphudLoggerService.logError("set user property: Invalid increment property type")
            return
        }

        let property = ApphudUserProperty(key: key.key, value: value, increment: increment, setOnce: setOnce, type: typeString)
        pendingUserProperties.removeAll { prop -> Bool in property.key == prop.key }
        pendingUserProperties.append(property)
        setNeedsToUpdateUserProperties = true
    }

    @objc internal func updateUserProperties() {
        setNeedsToUpdateUserProperties = false
        guard pendingUserProperties.count > 0 else {return}
        var params = [String: Any]()
        params["device_id"] = self.currentDeviceID

        var properties = [[String: Any?]]()
        pendingUserProperties.forEach { property in
            if let json = property.toJSON() {
                properties.append(json)
            }
        }
        params["properties"] = properties
        httpClient?.startRequest(path: "customers/properties", params: params, method: .post) { (result, _, _, error, code) in
            if result {
                self.pendingUserProperties.removeAll()
                apphudLog("User Properties successfully updated.")
            } else {
                apphudLog("User Properties update failed: \(error?.localizedDescription ?? "") with code: \(code)")
            }
        }
    }
}
