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

public typealias BoolCallback = (Bool) -> Void

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {

    var window: UIWindow?

    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {

        Apphud.start(apiKey: "app_4sY9cLggXpMDDQMmvc5wXUPGReMp8G")

        /** Custom User Properties Examples */
        Apphud.setUserProperty(key: .email, value: "user@example.com", setOnce: true)
        Apphud.setUserProperty(key: .init("custom_prop_1"), value: 0.5)
        Apphud.setUserProperty(key: .init("custom_prop_2"), value: true)
//        Apphud.incrementUserProperty(key: .init("coins_count"), by: 2)
        Apphud.setDelegate(self)
        Apphud.setUIDelegate(self)

        registerForNotifications()
        return true
    }

    func registerForNotifications() {
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (_, _) in }
        UIApplication.shared.registerForRemoteNotifications()
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

    func apphudDidFetchStoreKitProducts(_ products: [SKProduct]) {
        // handle this if needed
    }

    func apphudDidFetchStoreKitProducts(_ products: [SKProduct], _ error: Error?) {
        // handle this if needed
    }

    func apphudDidObservePurchase(result: ApphudPurchaseResult) -> Bool {

        print("Did observe purchase made without Apphud SDK: \(result)")

        return true // let apphud sdk to finish this transaction
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
