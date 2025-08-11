//
//  AppDelegate.swift
//  Apphud, Inc
//
//  Created by ren6 on 31/05/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import UIKit
import UserNotifications
import ApphudSDK
import StoreKit
import AppTrackingTransparency
import AdSupport

public typealias BoolCallback = (Bool) -> Void

@main
class AppDelegate: UIResponder, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        Task {
            await Apphud.logout()
            Task { @MainActor in
                self.startApphud()
            }
        }
        
        return true
    }
    
    func startApphud() {
        ApphudUtils.enableAllLogs()
        ApphudHttpClient.shared.domainUrlString = "https://gateway.apphudstage.com"
        Apphud.start(apiKey: "app_oBcXz2z9j8spKPL2T7sZwQaQN5Jzme")
        Apphud.setDeviceIdentifiers(idfa: nil, idfv: UIDevice.current.identifierForVendor?.uuidString)

        
        let data: [String: Any] = [
            "~feature": "paid advertising",
            "~advertising_partner_name": "Binom",
            "+clicked_branch_link": true,
            "~referring_browser": "Twitter",
            "~referring_link": "https://v35fv.app.link/Gq1FRVN4sLb?%243p=a_custom_1344019000161590306&%7Ead_id=d28rsn1nmdlc73f25olg&%7Esecondary_publisher=3&%7Ecampaign=HillTop_crash481+SafeConnect%28CPT%29+30may25&%7Echannel=5AI24G5808&%7Ead_set_id=10&%7Ead_group=test&%7Ead_set_name=AppleSecurity%28fixButton+noTouchCheck%29",
            "~ad_id": "d28rsn1nmdlc73f25olg",
            "~ad_set_id": "10",
            "+match_guaranteed": false,
            "~campaign": "HillTop_crash481 SafeConnect(CPT) 30may25",
            "+click_timestamp": 1754381977,
            "~ad_set_name": "AppleSecurity(fixButton noTouchCheck)",
            "~secondary_publisher": "3",
            "~branch_ad_format": "App Only",
            "$3p": "a_custom_1344019000161590306",
            "$link_title": "Binom link",
            "~channel": "5AI24G5808",
            "~ad_group": "test",
            "+is_first_session": true,
            "~id": "1344301159308973676"
        ]

        Apphud.setAttribution(data: ApphudAttributionData(rawData: ["branch_data": data]), from: .branch, callback: nil)

        
        /** Custom User Properties Examples */
        Apphud.setUserProperty(key: .email, value: "user@example.com", setOnce: true)
        Apphud.setUserProperty(key: .init("custom_prop_1"), value: 0.5)
        Apphud.setUserProperty(key: .init("custom_prop_2"), value: true)
        Apphud.incrementUserProperty(key: .init("coins_count"), by: 2)
//        Apphud.setDelegate(self)
        Apphud.setUIDelegate(self)
    }

    func registerForNotifications() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (_, _) in }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func fetchIDFA() {
        if #available(iOS 14.5, *) {
            DispatchQueue.main.asyncAfter(deadline: .now()+2.0) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    guard status == .authorized else {return}
                    let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                    Apphud.setDeviceIdentifiers(idfa: idfa, idfv: UIDevice.current.identifierForVendor?.uuidString)
                }
            }
        }
    }

    func application(_ application: UIApplication, didFailToRegisterForRemoteNotificationsWithError error: Error) {
        print("error: \(error)")
    }

    func application(_ application: UIApplication, didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data) {
        let tokenString = deviceToken.map { String(format: "%02.2hhx", $0) }.joined()
        print("device token = \(tokenString)")
        Apphud.submitPushNotificationsToken(token: deviceToken, callback: nil)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        Apphud.handlePushNotification(apsInfo: response.notification.request.content.userInfo)
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        Apphud.handlePushNotification(apsInfo: notification.request.content.userInfo)
        completionHandler([])
    }
}

extension AppDelegate: ApphudUIDelegate {

    func apphudScreenPresentationStyle(controller: UIViewController) -> UIModalPresentationStyle {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .pageSheet
        } else {
            return .overFullScreen
        }
    }
}

extension AppDelegate: @preconcurrency ApphudDelegate {
    func userDidLoad(rawPaywalls: [ApphudSDK.ApphudPaywall], rawPlacements: [ApphudSDK.ApphudPlacement]?) {
        print("User loaded, paywalls and placements are available")
    }

    func paywallsDidFullyLoad(paywalls: [ApphudPaywall]) {
        print("paywalls are ready")
    }

    func placementsDidFullyLoad(placements: [ApphudPlacement]) {
        print("placements are ready")
    }
}
