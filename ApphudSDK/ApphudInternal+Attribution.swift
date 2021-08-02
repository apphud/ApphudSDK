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
    internal func addAttribution(data: [AnyHashable: Any]?, from provider: ApphudAttributionProvider, identifer: String? = nil, callback: ((Bool) -> Void)?) {
        performWhenUserRegistered {

            var params: [String: Any] = ["device_id": self.currentDeviceID]

            switch provider {
            case .firebase:
                guard identifer != nil, self.submittedFirebaseId != identifer else {
                    callback?(false)
                    return
                }
                params["firebase_id"] = identifer
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
            case .appleAdsAttribution:
                guard identifer != nil else {
                    callback?(false)
                    return
                }
                guard !self.didSubmitAppleAdsAttribution else {
                    apphudLog("Already submitted Apple Ads Attribution, exiting", forceDisplay: true)
                    callback?(false)
                    return
                }
                self.getAppleAttribution(identifer!) {(appleAttributionData) in
                    if appleAttributionData != nil {
                        params["search_ads_data"] = appleAttributionData
                        self.startAttributionRequest(params: params, provider: provider, identifer: identifer) { result in
                            callback?(result)
                        }
                    }
                }
                return
            case .facebook:
                var hash: [AnyHashable: Any] = ["fb_device": true]

                if apphudNeedsToCollectFBAnonID(), let anonID = apphudGetFBAnonID() {
                    hash["anon_id"] = anonID
                }
                if let extInfo = apphudGetFBExtInfo() {
                    hash["extinfo"] = extInfo
                }
                if data != nil {
                    hash.merge(data!, uniquingKeysWith: {_, new in new})
                }
                params["facebook_data"] = hash
            }
            
            // to avoid 404 problems on backend
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startAttributionRequest(params: params, provider: provider, identifer: identifer) { result in
                    callback?(result)
                }
            }
        }
    }
    
    func startAttributionRequest(params: [String: Any], provider: ApphudAttributionProvider, identifer:String?, callback: ((Bool) -> Void)?) {
        self.httpClient?.startRequest(path: "customers/attribution", params: params, method: .post) { (result, _, _, _, _) in
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
            case .facebook:
                if result {
                    self.didSubmitFacebookAttribution = true
                }
            case .firebase:
                if result {
                    self.submittedFirebaseId = identifer
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
                ApphudLoggerService.logError(message)
            }
            
            callback?(result)
        }
    }
    
    @objc internal func getAppleAttribution(_ appleAttibutionToken:String, completion: @escaping ([AnyHashable: Any]?) -> Void) {
        let request = NSMutableURLRequest(url: URL(string:"https://api-adservices.apple.com/api/v1/")!)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(appleAttibutionToken.utf8)
        
        let task = URLSession.shared.dataTask(with: request as URLRequest) { (data, _, error) in
            
            if let data = data,
               let result = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
               let campaignId = result["campaignId"] as? Int,
               campaignId != 1234567890,
               let attribution = result["attribution"] as? Bool,
               attribution == true {
                    completion(result)
                    return
                }
            completion(nil)
        }
        task.resume()
    }
    
    @objc internal func forceSendAttributionDataIfNeeded() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(forceSendAttributionDataIfNeeded), object: nil)
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
