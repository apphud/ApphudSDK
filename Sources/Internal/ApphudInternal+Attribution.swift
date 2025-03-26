//
//  ApphudInternal+Attribution.swift
//  apphud
//
//  Created by Renat on 01.07.2020.
//  Copyright © 2020 Apphud Inc. All rights reserved.
//

import Foundation

extension ApphudInternal {
    
    // MARK: - Attribution
    internal func setAttribution(data: ApphudAttributionData?, from provider: ApphudAttributionProvider, identifer: String? = nil, callback: ((Bool) -> Void)?) {
        performWhenUserRegistered {
            Task {
                var dict: [String: any Sendable] = data?.rawData as? [String: any Sendable] ?? [:]
            
                switch provider {
                    // ---------- .custom ----------
                case .custom:
                    dict["identifier"] = identifer
                    break
                    
                    // ---------- .voluum ----------
                case .voluum:
                    dict["identifier"] = identifer
                    break
                    
                    // ---------- .singular ----------
                case .singular:
                    dict["identifier"] = identifer
                    break
                    
                    // ---------- .tenjin ----------
                case .tenjin:
                    dict["identifier"] = identifer
                    break

                    // ---------- .tiktok ----------
                case .tiktok:
                    dict["identifier"] = identifer
                    break

                    // ---------- .branch ----------
                case .branch:
                    dict["identifier"] = identifer
                    break

                    // ---------- .facebook ----------
                case .facebook:
                    guard let fbIdent = identifer,
                          self.submittedFacebookAnonId != fbIdent
                    else {
                        apphudLog("Facebook Anon ID (identifer field) is nil or didn't change, exiting", forceDisplay: true)
                        callback?(false)
                        return
                    }
                    dict["fb_anon_id"] = fbIdent

                    // ---------- .firebase ----------
                case .firebase:
                    guard let firebaseId = identifer,
                          self.submittedFirebaseId != firebaseId
                    else {
                        callback?(false)
                        return
                    }
                    dict["firebase_id"] = firebaseId

                    // ---------- .appsFlyer ----------
                case .appsFlyer:
                    guard let afIdent = identifer else {
                        callback?(false)
                        return
                    }
                    guard !self.isSendingAppsFlyer else {
                        apphudLog("Already submitted AppsFlyer attribution, skipping", forceDisplay: true)
                        callback?(false)
                        return
                    }

                    dict["appsflyer_id"] = afIdent

                    guard await self.submittedPreviouslyAF(data: dict) else {
                        apphudLog("Already submitted AppsFlyer attribution, skipping", forceDisplay: true)
                        callback?(false)
                        return
                    }
                    self.isSendingAppsFlyer = true

                    // ---------- .adjust ----------
                case .adjust:
                    guard !self.isSendingAdjust else {
                        apphudLog("Already submitted Adjust attribution, skipping", forceDisplay: true)
                        callback?(false)
                        return
                    }
                    if let adid = identifer {
                        dict["adid"] = adid
                    }

                    guard await self.submittedPreviouslyAdjust(data: dict) else {
                        apphudLog("Already submitted Adjust attribution, skipping", forceDisplay: true)
                        callback?(false)
                        return
                    }
                    self.isSendingAdjust = true

                    // ---------- .appleAdsAttribution ----------
                case .appleAdsAttribution:
                    guard let token = identifer else {
                        callback?(false)
                        return
                    }
                    guard !self.didSubmitAppleAdsAttribution else {
                        apphudLog("Already submitted Apple Ads Attribution, exiting", forceDisplay: true)
                        callback?(false)
                        return
                    }

                    if let searchAdsData = await self.getAppleAttribution(token) {
                        for (key, value) in searchAdsData {
                            dict[key] = value
                        }
                    } else {
                        callback?(false)
                        return
                    }

                default:
                    break
                }
                                
                // Create Request params with raw_data
                var params: [String: Any] = [
                    "device_id": self.currentDeviceID,
                    "provider": provider.toString(),
                    "raw_data": dict
                ]

                var attributionDict: [String: any Sendable] = [:]
                
                if let data = data {
                    if let adNetwork = data.adNetwork          { attributionDict["ad_network"]    = adNetwork }
                    if let channel = data.channel              { attributionDict["channel"]  = channel }
                    if let campaign = data.campaign            { attributionDict["campaign"]      = campaign }
                    if let adSet = data.adSet                  { attributionDict["ad_set"]        = adSet }
                    if let creative = data.creative            { attributionDict["creative"]      = creative }
                    if let keyword = data.keyword              { attributionDict["keyword"]       = keyword }
                    if let custom1 = data.custom1              { attributionDict["custom_1"]      = custom1 }
                    if let custom2 = data.custom2              { attributionDict["custom_2"]      = custom2 }
                }
                params["attribution"] = attributionDict
                
                try? await Task.sleep(nanoseconds: 2_000_000_000)
                
                self.startAttributionRequest(params: params, apiVersion:.APIV2, provider: provider, identifer: identifer) { result in
                    Task {
                        if result {
                            switch provider {
                            case .appsFlyer:
                                await ApphudDataActor.shared.setAFData(dict)
                            case .adjust:
                                await ApphudDataActor.shared.setAdjustData(dict)
                            case .firebase:
                                self.submittedFirebaseId = identifer
                            case .facebook:
                                self.submittedFacebookAnonId = identifer
                            case .appleAdsAttribution:
                                self.didSubmitAppleAdsAttribution = true
                            default:
                                break
                            }
                        }
                    }
                    callback?(result)
                }
            }
        }
    }
    
    func submittedPreviouslyAF(data: [String: any Sendable]) async -> Bool {
        return await self.compareAttribution(first: data, second: ApphudDataActor.shared.submittedAFData ?? [:])
    }

    func submittedPreviouslyAdjust(data: [String: any Sendable]) async -> Bool {
        return await self.compareAttribution(first: data, second: ApphudDataActor.shared.submittedAdjustData ?? [:])
    }

    func compareAttribution(first: [String: any Sendable], second: [String: any Sendable]) -> Bool {
        let dictionary1 = NSDictionary(dictionary: first)
        let dictionary2 = NSDictionary(dictionary: second)

        return !dictionary1.isEqual(to: dictionary2 as! [AnyHashable: Any])
    }

    func startAttributionRequest(params: [String: Any], apiVersion: ApphudHttpClient.ApphudApiVersion = .APIV1, provider: ApphudAttributionProvider, identifer: String?, callback: ((Bool) -> Void)?) {
        self.httpClient?.startRequest(path: .attribution, apiVersion: apiVersion, params: params, method: .post, retry: true) { (result, _, _, _, _, _, _) in
            switch provider {
            case .adjust:
                // to avoid sending the same data several times in a row
                DispatchQueue.main.asyncAfter(deadline: .now()+1.0) {
                    self.isSendingAdjust = false
                }
                if result {
                    self.didSubmitAdjustAttribution = true
                }
            case .appsFlyer:
                // to avoid sending the same data several times in a row
                DispatchQueue.main.asyncAfter(deadline: .now()+5.0) {
                    self.isSendingAppsFlyer = false
                }
                if result {
                    self.didSubmitAppsFlyerAttribution = true
                }
            case .firebase:
                if result {
                    self.submittedFirebaseId = identifer
                }
            case .facebook:
                if result {
                    self.submittedFacebookAnonId = identifer
                }
            case .appleAdsAttribution:
                if result {
                    self.didSubmitAppleAdsAttribution = true
                }
            default:
                break
            }

            if result {
                apphudLog("Did send \(provider.toString()) attribution data to Apphud!")
            } else {
                let message = "Failed to send \(provider.toString()) attribution data to Apphud!"
                apphudLog(message)
            }

            callback?(result)
        }
    }

    @MainActor
    @objc internal func forceSendAttributionDataIfNeeded() {
        /* This functionality has been removed since 3.2.8
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(forceSendAttributionDataIfNeeded), object: nil)
        automaticallySubmitAppsFlyerAttributionIfNeeded()
        automaticallySubmitAdjustAttributionIfNeeded()
         */
    }

    @objc internal func getAppleAttribution(_ appleAttibutionToken: String) async -> [String: any Sendable]? {

        var request = URLRequest(url: URL(string: "https://api-adservices.apple.com/api/v1/")!)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(appleAttibutionToken.utf8)

        let response = try? await URLSession.shared.data(for: request, retries: 5, delay: 7.0)
        if let data = response?.0,
           let result = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: any Sendable],
           let attribution = result["attribution"] as? Bool {
            if attribution {
                return result
            } else {
                return nil
            }
        } else {
            return ["token": appleAttibutionToken]
        }
    }
    
    @MainActor
    internal func tryWebAttribution(attributionData: [AnyHashable: Any], completion: @escaping (Bool, ApphudUser?) -> Void) {
        
        let userId = (attributionData["aph_user_id"] ?? attributionData["apphud_user_id"]) as? String ?? ""
        let email = (attributionData["email"] ?? attributionData["apphud_user_email"]) as? String ?? ""

        if userId.isEmpty && email.isEmpty {
            completion(false, currentUser)
            return
        }
        
        if (email.isEmpty && currentUser?.userId == userId) {
            apphudLog("Already web2web user, skipping")
            completion(true, currentUser)
            return
        }
        
        var params: [String: Any] = ["from_web2web": true]
        if !userId.isEmpty {
            params["user_id"] = userId
        }
        if !email.isEmpty {
            params["email"] = email
        }
        
        apphudLog("Found a match from web click, updating User ID to \(userId)", forceDisplay: true)
        self.performWhenUserRegistered {
            self.updateUser(fields: params) { (result, _, data, _, _, _, attempts) in
                if result {
                    Task {
                        let changes = await self.parseUser(data: data)
                        
                        Task { @MainActor in
                            self.notifyAboutUpdates(changes)
                            completion(true, self.currentUser)
                        }
                    }
                } else {
                    completion(false, self.currentUser)
                }
            }
        }
    }
}
