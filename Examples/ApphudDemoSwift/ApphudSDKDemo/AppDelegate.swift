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

        Apphud.start(apiKey: "YOUR_API_KEY")
        Apphud.setDeviceIdentifiers(idfa: nil, idfv: UIDevice.current.identifierForVendor?.uuidString)
//        fetchIDFA()

        Apphud.preloadPaywallScreens(placementIdentifiers: ["MY_PLAYWALL_PLACEMENT_ID", "ANOTHER_PLACEMENT_ID"])

        /** Custom User Properties Examples */
        Apphud.setUserProperty(key: .email, value: "user@example.com", setOnce: true)
        Apphud.setUserProperty(key: .init("custom_prop_1"), value: 0.5)
        Apphud.setUserProperty(key: .init("custom_prop_2"), value: true)
        Apphud.incrementUserProperty(key: .init("coins_count"), by: 2)
//        Apphud.setDelegate(self)
        Apphud.setUIDelegate(self)
//        registerForNotifications()

        return true
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
