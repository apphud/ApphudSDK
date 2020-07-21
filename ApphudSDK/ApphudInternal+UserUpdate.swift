//
//  ApphudInternal+Registration.swift
//  apphud
//
//  Created by Renat on 01.07.2020.
//  Copyright © 2020 softeam. All rights reserved.
//

import Foundation

extension ApphudInternal {

    @discardableResult internal func parseUser(_ dict: [String: Any]?) -> HasPurchasesChanges {

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

    internal func createOrGetUser(shouldUpdateUserID: Bool, callback: @escaping (Bool) -> Void) {

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
                if self.requiresReceiptSubmission {
                    self.submitAppStoreReceipt()
                }
            }

            if error != nil {
                apphudLog("Failed to register or get user, error:\(error!.localizedDescription)", forceDisplay: true)
            }

            callback(finalResult)
        }
    }

    internal func updateUserCurrencyIfNeeded(priceLocale: Locale?) {
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

    internal func refreshCurrentUser() {
        createOrGetUser(shouldUpdateUserID: false) { _ in
            self.lastCheckDate = Date()
        }
    }
}
