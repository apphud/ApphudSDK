//
//  ApphudInternal+Attribution.swift
//  apphud
//
//  Created by Renat on 01.07.2020.
//  Copyright © 2020 Apphud Inc. All rights reserved.
//

import Foundation

@available(OSX 10.14.4, *)
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
                    apphudLog("Already submitted AppsFlyer attribution, skipping", forceDisplay: true)
                    callback?(false)
                    return
                }
                params["appsflyer_id"] = identifer
                
                if data != nil {
                    params["appsflyer_data"] = data
                    
                    guard self.submittedPreviouslyAF(data: data!) else {
                        apphudLog("Already submitted AppsFlyer attribution, skipping", forceDisplay: true)
                        callback?(false)
                        return
                    }
                }
                self.isSendingAppsFlyer = true
            case .adjust:
                guard !self.isSendingAdjust else {
                    apphudLog("Already submitted Adjust attribution, skipping", forceDisplay: true)
                    callback?(false)
                    return
                }
                if data != nil {
                    params["adjust_data"] = data
                    
                    guard self.submittedPreviouslyAdjust(data: data!) else {
                        apphudLog("Already submitted Adjust attribution, skipping", forceDisplay: true)
                        callback?(false)
                        return
                    }
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
                self.getAppleAttribution(identifer!) {(appleAttributionData, isAttributionExist) in
                    if let data = appleAttributionData {
                        if isAttributionExist {
                            params["search_ads_data"] = data
                        } else {
                            callback?(false)
                        }
                    } else {
                        params["search_ads_data"] = ["token": identifer]
                    }
                                        
                    self.startAttributionRequest(params: params, provider: provider, identifer: identifer) { result in
                        callback?(result)
                    }
                }
                return
            default:
                return
            }

            // to avoid 404 problems on backend
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self.startAttributionRequest(params: params, provider: provider, identifer: identifer) { result in
                    if result {
                        switch provider {
                        case .appsFlyer:
                            self.submittedAFData = data
                        case .adjust:
                            self.submittedAdjustData = data
                        default :
                            break
                        }
                    }
                    callback?(result)
                }
            }
        }
    }

    func submittedPreviouslyAF(data: [AnyHashable: Any]) -> Bool {
        return self.compareAttribution(first: data, second: self.submittedAFData ?? [:])
    }

    func submittedPreviouslyAdjust(data: [AnyHashable: Any]) -> Bool {
        return self.compareAttribution(first: data, second: self.submittedAdjustData ?? [:])
    }

    func compareAttribution(first: [AnyHashable: Any], second: [AnyHashable: Any]) -> Bool {
        let dictionary1 = NSDictionary(dictionary: first)
        let dictionary2 = NSDictionary(dictionary: second)

        return !dictionary1.isEqual(to: dictionary2 as! [AnyHashable: Any])
    }

    func startAttributionRequest(params: [String: Any], provider: ApphudAttributionProvider, identifer: String?, callback: ((Bool) -> Void)?) {
        self.httpClient?.startRequest(path: .attribution, params: params, method: .post) { (result, _, _, _, _, _) in
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

    @objc internal func forceSendAttributionDataIfNeeded() {
        NSObject.cancelPreviousPerformRequests(withTarget: self, selector: #selector(forceSendAttributionDataIfNeeded), object: nil)
        automaticallySubmitAppsFlyerAttributionIfNeeded()
        automaticallySubmitAdjustAttributionIfNeeded()
    }
    
    @objc internal func getAppleAttribution(_ appleAttibutionToken: String, completion: @escaping ([AnyHashable: Any]?, Bool) -> Void) {
        let request = NSMutableURLRequest(url: URL(string: "https://api-adservices.apple.com/api/v1/")!)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(appleAttibutionToken.utf8)
        
        let task = URLSession.shared.dataTask(with: request as URLRequest) { (data, _, _) in
            
            if let data = data,
               let result = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
               let attribution = result["attribution"] as? Bool {
                completion(result, attribution)
            }
            completion(nil, false)
        }
        task.resume()
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
}
