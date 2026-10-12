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
    internal func setAttribution(data: ApphudAttributionData?, from provider: ApphudAttributionProvider, identifer: String? = nil, callback: ((Bool, [String: Any]?) -> Void)?) {
        performWhenUserRegistered {
            Task {
                var dict: [String: any Sendable] = data?.rawData as? [String: any Sendable] ?? [:]

                switch provider {
// ---------- .custom ----------
                case .custom:
                    dict["identifier"] = identifer
// ---------- .voluum ----------
                                    case .voluum:
                    dict["identifier"] = identifer
// ---------- .singular ----------
                                    case .singular:
                    dict["identifier"] = identifer
// ---------- .tenjin ----------
                                    case .tenjin:
                    dict["identifier"] = identifer
// ---------- .tiktok ----------
                                    case .tiktok:
                    dict["identifier"] = identifer
// ---------- .branch ----------
                                    case .branch:
                    dict["identifier"] = identifer

                    // ---------- .facebook ----------
                case .facebook:
                    guard let fbIdent = identifer,
                          self.submittedFacebookAnonId != fbIdent
                    else {
                        apphudLog("Facebook Anon ID (identifer field) is nil or didn't change, exiting", forceDisplay: true)
                        callback?(false, nil)
                        return
                    }
                    dict["fb_anon_id"] = fbIdent

                    // ---------- .firebase ----------
                case .firebase:
                    guard let firebaseId = identifer,
                          self.submittedFirebaseId != firebaseId
                    else {
                        callback?(false, nil)
                        return
                    }
                    dict["firebase_id"] = firebaseId

                    // ---------- .appsFlyer ----------
                case .appsFlyer:
                    guard let afIdent = identifer else {
                        callback?(false, nil)
                        return
                    }
                    guard !self.isSendingAppsFlyer else {
                        apphudLog("Already submitted AppsFlyer attribution, skipping", forceDisplay: true)
                        callback?(false, nil)
                        return
                    }

                    dict["appsflyer_id"] = afIdent

                    guard await self.submittedPreviouslyAF(data: dict) else {
                        apphudLog("Already submitted AppsFlyer attribution, skipping", forceDisplay: true)
                        callback?(false, nil)
                        return
                    }
                    self.isSendingAppsFlyer = true

                    // ---------- .adjust ----------
                case .adjust:
                    guard !self.isSendingAdjust else {
                        apphudLog("Already submitted Adjust attribution, skipping", forceDisplay: true)
                        callback?(false, nil)
                        return
                    }
                    if let adid = identifer {
                        dict["adid"] = adid
                    }

                    guard await self.submittedPreviouslyAdjust(data: dict) else {
                        apphudLog("Already submitted Adjust attribution, skipping", forceDisplay: true)
                        callback?(false, nil)
                        return
                    }
                    self.isSendingAdjust = true

                    // ---------- .appleAdsAttribution ----------
                case .appleAdsAttribution:
                    guard let token = identifer else {
                        callback?(false, nil)
                        return
                    }
                    guard !self.didSubmitAppleAdsAttribution else {
                        apphudLog("Already submitted Apple Ads Attribution, exiting", forceDisplay: true)
                        callback?(false, nil)
                        return
                    }

                    if let searchAdsData = await self.getAppleAttribution(token) {
                        for (key, value) in searchAdsData {
                            dict[key] = value
                        }
                    } else {
                        callback?(false, nil)
                        return
                    }

                default:
                    break
                }

                // Create Request params with raw_data
                var params: [String: Any] = self.identityParams()
                params["provider"] = provider.toString()
                params["raw_data"] = dict

                var attributionDict: [String: any Sendable] = [:]

                if let data = data {
                    if let adNetwork = data.adNetwork { attributionDict["ad_network"]    = adNetwork }
                    if let channel = data.channel { attributionDict["channel"]  = channel }
                    if let campaign = data.campaign { attributionDict["campaign"]      = campaign }
                    if let adSet = data.adSet { attributionDict["ad_set"]        = adSet }
                    if let creative = data.creative { attributionDict["creative"]      = creative }
                    if let keyword = data.keyword { attributionDict["keyword"]       = keyword }
                    if let custom1 = data.custom1 { attributionDict["custom_1"]      = custom1 }
                    if let custom2 = data.custom2 { attributionDict["custom_2"]      = custom2 }
                }
                params["attribution"] = attributionDict

                try? await Task.sleep(nanoseconds: 1_000_000_000)

                self.startAttributionRequest(params: params, apiVersion: .APIV2, provider: provider, identifer: identifer) { result in
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
                    callback?(result, params)
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
    internal func requestDeferredDeeplinkAttribution() {
        performWhenUserRegistered {
            self.webController = ApphudWebController()
            self.webController?.present { visitorId in
                self.startDeeplinkAttributionRequest(url: nil, visitorId: visitorId) { response in
                    Task { @MainActor in
                        self.notifyDeeplinkAttribution(attribution: response ?? [:], kind: .deferred, url: nil)
                    }
                }
            }
        }
    }
    
    @MainActor
    internal func setDeeplinkAttributionHandler(_ handler: ApphudDeeplinkHandler?) {
        self.deeplinkAttributionHandler = handler
    }
    
    @MainActor
    internal func notifyDeeplinkAttribution(attribution: [String: Any], kind: ApphudDeeplinkAttributionKind, url: URL?) {
        self.deeplinkAttributionHandler?(attribution, kind, url)
    }
    
    internal func handleOpenURL(_ url: URL) {
        self.forceDirectDeeplinkAttribution(url: url) { result in
            Task { @MainActor in
                self.notifyDeeplinkAttribution(attribution: result, kind: .direct, url: url)
            }
        }
    }
    
    internal func forceDirectDeeplinkAttribution(url: URL, completion: @escaping ([String: Any]) -> Void) {
        performWhenUserRegistered {
            self.startDeeplinkAttributionRequest(url: url, visitorId: nil) { response in
                completion(response ?? [:])
            }
        }
    }
    
    private func startDeeplinkAttributionRequest(url: URL?, visitorId: String?, completion: @escaping ([String: Any]?) -> Void) {
        var params: [String: Any] = self.identityParams()
        params["bundle_id"] = Bundle.main.bundleIdentifier ?? ""
        if let url {
            params["url"] = url.absoluteString
        }
        if let visitorId {
            params["visitor_id"] = visitorId
        }
        
        self.httpClient?.startRequest(path: .attributionDeeplink, apiVersion: .APIV2, params: params, method: .post, useDecoder: false, retry: false, requestID: nil) { _, response, _, _, _, _, _ in
            apphudLog("response: \(String(describing: response))")
            completion(response)
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

        if !userId.isEmpty && identifiedUserID == userId {
            apphudLog("Already web2web user, skipping")
            completion(true, currentUser)
            return
        }

        apphudLog("Found a match from web click, updating User ID to \(userId)", forceDisplay: true)
        self.performWhenUserRegistered {
            if !userId.isEmpty {
                // The web user's id is known: a plain identify, no from_web2web.
                self.applyIdentify(userID: userId)
                self.updateUser(fields: [:]) { (result, _, data, _, _, _, _) in
                    self.finishWebAttribution(result: result, data: data, adoptFromCustomer: nil, completion: completion)
                }
            } else {
                // Email only: the old request shape; the response names the web user.
                let params: [String: Any] = ["from_web2web": true, "email": email]
                // In fallback mode the local user is made up: no customer id to compare against.
                let customerBefore: String?? = self.fallbackMode ? nil : .some(self.currentUser?.internalId)
                self.updateUser(fields: params, legacyWeb2Web: true) { (result, _, data, _, _, _, _) in
                    self.finishWebAttribution(result: result, data: data, adoptFromCustomer: customerBefore, completion: completion)
                }
            }
        }
    }

    /// The web user an email-only web-to-web request found: the response is another customer than
    /// before. Without a match the backend returns the same customer, possibly with another
    /// install's id as its user_id, which is no user to adopt.
    internal static func webUserToAdopt(customerBefore: String?, response: ApphudUser?, anonymousID: String) -> String? {
        guard let response, !response.userId.isEmpty, response.userId != anonymousID,
              !response.internalId.isEmpty, response.internalId != customerBefore else { return nil }
        return response.userId
    }

    /// `adoptFromCustomer`: the customer id before an email-only request, `nil` for a request with the user id.
    private func finishWebAttribution(result: Bool, data: Data?, adoptFromCustomer customerBefore: String??, completion: @escaping (Bool, ApphudUser?) -> Void) {
        guard result else {
            Task { @MainActor in completion(false, self.currentUser) }
            return
        }
        Task {
            let changes = await self.parseUser(data: data)

            Task { @MainActor in
                // The web user found by email becomes the SDK's user, as an identify would; the
                // anonymous customer merges into it on the next request.
                if let customerBefore,
                   let webUserID = Self.webUserToAdopt(customerBefore: customerBefore, response: self.currentUser, anonymousID: self.currentAnonymousID) {
                    self.applyIdentify(userID: webUserID)
                }
                self.notifyAboutUpdates(changes)
                completion(true, self.currentUser)
            }
        }
    }
}
