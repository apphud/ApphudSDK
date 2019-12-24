//
//  AppDelegate.swift
//  apphud
//
//  Created by ren6 on 31/05/2019.
//  Copyright © 2019 Softeam. All rights reserved.
//

import UIKit
import UserNotifications

public typealias BoolCallback = (Bool) -> Void

@UIApplicationMain
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate {
    
    var window: UIWindow?
    
    var canShowApphudScreen = true
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        
        Apphud.enableDebugLogs()    
        Apphud.setUIDelegate(self)
//        canShowApphudScreen = false
        ApphudHttpClient.shared.domain_url_string = "https://api.bitcolio.com"
        
        Apphud.start(apiKey: "app_MDn9JRkSZzLMHtsFzWJXrscF7tZnis", userID: "renat_98.2", deviceID: "device_98.2")
        
//        DispatchQueue.main.asyncAfter(deadline: .now() + 13) { 
//            self.canShowApphudScreen = true
//            Apphud.showPendingScreen()
//        }
        
//        Apphud.start(apiKey: "YOUR_SDK_TOKEN")
        
        registerForNotifications()
        
        return true
    }
    
    func registerForNotifications(){
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (granted, error) in }      
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

extension AppDelegate : ApphudUIDelegate {
    
    func apphudShouldShowScreen(controller: UIViewController) -> Bool {
        return canShowApphudScreen
    }
    
    func apphudScreenPresentationStyle(controller: UIViewController) -> UIModalPresentationStyle {
        
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .pageSheet
        } else {
            return .overFullScreen
        }
    }
    
    func apphudDidDismissScreen(controller: UIViewController) {
        print("did dismiss screen")
    }    
}
