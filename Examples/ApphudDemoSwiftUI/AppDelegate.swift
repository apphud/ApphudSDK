//
//  AppDelegate.swift
//  ApphudDemoSwiftUI
//
//  Created by Renat Kurbanov on 15.02.2023.
//

import Foundation
import UIKit
import UserNotifications
import ApphudSDK
import AdSupport
import AppTrackingTransparency

class AppDelegate: NSObject, UIApplicationDelegate, @preconcurrency UNUserNotificationCenterDelegate {

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        #if DEBUG
        Apphud.enableDebugLogs()
        #endif
        Apphud.start(apiKey: "app_4sY9cLggXpMDDQMmvc5wXUPGReMp8G")
        Apphud.setDeviceIdentifiers(idfa: nil, idfv: UIDevice.current.identifierForVendor?.uuidString)
        fetchIDFA()

        /** Custom User Properties Examples */
        //        Apphud.setUserProperty(key: .email, value: "user@example.com", setOnce: true)
        //        Apphud.setUserProperty(key: .init("custom_prop_1"), value: 0.5)
        //        Apphud.setUserProperty(key: .init("custom_prop_2"), value: true)
        //        Apphud.incrementUserProperty(key: .init("coins_count"), by: 2)
        //        Apphud.setDelegate(self)
        Apphud.setUIDelegate(self)

        registerForNotifications()

        return true
    }

    func registerForNotifications() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
        UIApplication.shared.registerForRemoteNotifications()
    }

    func fetchIDFA() {
        DispatchQueue.main.asyncAfter(deadline: .now()+2.0) {
            if #available(iOS 14.5, *) {
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

extension AppDelegate: ApphudDelegate {
    func userDidLoad(rawPaywalls: [ApphudSDK.ApphudPaywall], rawPlacements: [ApphudSDK.ApphudPlacement]?) {

    }
}

extension AppDelegate: ApphudUIDelegate {

}
