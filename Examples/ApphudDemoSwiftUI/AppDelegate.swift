//
//  AppDelegate.swift
//  ApphudDemoSwiftUI
//
//  Created by Renat Kurbanov on 15.02.2023.
//

import Foundation
import UIKit
import UserNotifications
import AdSupport
import AppTrackingTransparency
import AppMetricaCore
import ApphudSDK
import StoreKit

class AppDelegate: NSObject, UIApplicationDelegate {

    var storekit2Observer: AsyncTransactionObserver!
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil) -> Bool {

        storekit2Observer = AsyncTransactionObserver()
        
//        #if DEBUG
//        Apphud.enableDebugLogs()
//        #endif
//        Apphud.start(apiKey: "app_4sY9cLggXpMDDQMmvc5wXUPGReMp8G")
//        Apphud.setDeviceIdentifiers(idfa: nil, idfv: UIDevice.current.identifierForVendor?.uuidString)
//        fetchIDFA()
//
//        /** Custom User Properties Examples */
//        //        Apphud.setUserProperty(key: .email, value: "user@example.com", setOnce: true)
//        //        Apphud.setUserProperty(key: .init("custom_prop_1"), value: 0.5)
//        //        Apphud.setUserProperty(key: .init("custom_prop_2"), value: true)
//        //        Apphud.incrementUserProperty(key: .init("coins_count"), by: 2)
//        //        Apphud.setDelegate(self)
//        Apphud.setUIDelegate(self)
        
        
        
        ApphudUtils.enableAllLogs()
        Task {
            if UserDefaults.standard.bool(forKey: "launched") == false {
//                await Apphud.logout()
            }
            
            UserDefaults.standard.set(true, forKey: "launched")
            
            let configuration = AppMetricaConfiguration(apiKey: "6544a04b-0f21-497f-bbc4-85f80384bbb3")
            configuration?.revenueAutoTrackingEnabled = false
//            configuration?.areLogsEnabled = true
            AppMetrica.clearAppEnvironment()
            AppMetrica.activate(with: configuration!)
            
            Task {
                try? await Task.sleep(nanoseconds: 5_000_000_000)
                let profileID = AppMetrica.userProfileID
                let deviceID = AppMetrica.deviceID
               let apphudUserID = Apphud.userID()
                let apphudDeviceID = Apphud.deviceID()
                
                print("profle_id = \(profileID), device_id = \(deviceID), aph_user_id = \(apphudUserID), aph_device_id = \(apphudDeviceID)")
            }
        }
                
//        registerForNotifications()
        

        return true
    }
    
    

    func registerForNotifications() {
//        UNUserNotificationCenter.current().delegate = self
//        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { _, _ in }
//        UIApplication.shared.registerForRemoteNotifications()
    }
    
    func fetchIDFA() {
        DispatchQueue.main.asyncAfter(deadline: .now()+2.0) {
            if #available(iOS 14.5, *) {
                ATTrackingManager.requestTrackingAuthorization { status in
                    guard status == .authorized else {return}
                    let idfa = ASIdentifierManager.shared().advertisingIdentifier.uuidString
                    
//                    Apphud.setDeviceIdentifiers(idfa: idfa, idfv: UIDevice.current.identifierForVendor?.uuidString)
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
//        Apphud.submitPushNotificationsToken(token: deviceToken, callback: nil)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
//        Apphud.handlePushNotification(apsInfo: response.notification.request.content.userInfo)
        completionHandler()
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
//        Apphud.handlePushNotification(apsInfo: notification.request.content.userInfo)
        completionHandler([])
    }
}
//
//extension AppDelegate: ApphudDelegate {
//    func userDidLoad(rawPaywalls: [ApphudSDK.ApphudPaywall], rawPlacements: [ApphudSDK.ApphudPlacement]?) {
//
//    }
//}
//
//extension AppDelegate: ApphudUIDelegate {
//
//}


@available(iOS 15.0, macOS 12.0, tvOS 15.0, watchOS 8.0, *)
final class AsyncTransactionObserver {

    var updates: Task<Void, Never>?

    init() {
        updates = newTransactionListenerTask()
    }

    deinit {
        updates?.cancel()
    }

    private func newTransactionListenerTask() -> Task<Void, Never> {
        Task(priority: .background) {
            for await verificationResult in StoreKit.Transaction.updates {
                guard case .verified(let transaction) = verificationResult else {
                    if case .unverified(_, _) = verificationResult {
                    }
                    return
                }

                print("Received transaction [\(transaction.id), \(transaction.productID)] from StoreKit2")
            }
        }
    }
}
