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
            Task {
                var params: [String: Any] = ["device_id": self.currentDeviceID]

                switch provider {
                case .custom:
                    if let customAttribution = data as? [String: Any] {
                        params.merge(customAttribution, uniquingKeysWith: { f, _ in f})
                    }
                case .facebook:
                    guard identifer != nil, self.submittedFacebookAnonId != identifer else {
                        apphudLog("Facebook Anon ID is nil or didn't change, exiting", forceDisplay: true)
                        callback?(false)
                        return
                    }
                    params["fb_anon_id"] = identifer
                    if let customAttribution = data as? [String: Any] {
                        params.merge(customAttribution, uniquingKeysWith: { f, _ in f})
                    }
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

                        guard await self.submittedPreviouslyAF(data: data!) else {
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

                        guard await self.submittedPreviouslyAdjust(data: data!) else {
                            apphudLog("Already submitted Adjust attribution, skipping", forceDisplay: true)
                            callback?(false)
                            return
                        }
                    }
                    self.isSendingAdjust = true
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

                    if let searchAdsData = await self.getAppleAttribution(identifer!) {
                        params["search_ads_data"] = searchAdsData
                    } else {
                        callback?(false)
                        return
                    }
                default:
                    return
                }

                // to avoid 404 problems on backend
                try? await Task.sleep(nanoseconds: 2_000_000_000)

                self.startAttributionRequest(params: params, provider: provider, identifer: identifer) { result in
                    Task {
                        if result {
                            switch provider {
                            case .appsFlyer:
                                await ApphudDataActor.shared.setAFData(data)
                            case .adjust:
                                await ApphudDataActor.shared.setAdjustData(data)
                            default :
                                break
                            }
                        }
                    }
                    callback?(result)
                }
            }
        }
    }

    func submittedPreviouslyAF(data: [AnyHashable: Any]) async -> Bool {
        return await self.compareAttribution(first: data, second: ApphudDataActor.shared.submittedAFData ?? [:])
    }

    func submittedPreviouslyAdjust(data: [AnyHashable: Any]) async -> Bool {
        return await self.compareAttribution(first: data, second: ApphudDataActor.shared.submittedAdjustData ?? [:])
    }

    func compareAttribution(first: [AnyHashable: Any], second: [AnyHashable: Any]) -> Bool {
        let dictionary1 = NSDictionary(dictionary: first)
        let dictionary2 = NSDictionary(dictionary: second)

        return !dictionary1.isEqual(to: dictionary2 as! [AnyHashable: Any])
    }

    func startAttributionRequest(params: [String: Any], provider: ApphudAttributionProvider, identifer: String?, callback: ((Bool) -> Void)?) {
        self.httpClient?.startRequest(path: .attribution, params: params, method: .post, retry: true) { (result, _, _, _, _, _) in
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

    @objc internal func getAppleAttribution(_ appleAttibutionToken: String) async -> [AnyHashable: Any]? {

        var request = URLRequest(url: URL(string: "https://api-adservices.apple.com/api/v1/")!)
        request.httpMethod = "POST"
        request.setValue("text/plain", forHTTPHeaderField: "Content-Type")
        request.httpBody = Data(appleAttibutionToken.utf8)

        let response = try? await URLSession.shared.data(for: request, retries: 5, delay: 1.0)
        if let data = response?.0,
           let result = try? JSONSerialization.jsonObject(with: data, options: .allowFragments) as? [String: Any],
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
}
