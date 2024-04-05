//
//  AppDelegate.swift
//  sampleapp
//
//  Created by Apphud on 13.02.2024.
//  Copyright © 2024 Apphud. All rights reserved.
//

import UIKit
import ApphudSDK
import AppsFlyerLib
import FacebookCore
import Amplitude
import BranchSDK

@main
class AppDelegate: UIResponder, UIApplicationDelegate, UNUserNotificationCenterDelegate, AppsFlyerLibDelegate {
    // MARK: - AppsFlyer delegate
    func onConversionDataSuccess(_ conversionInfo: [AnyHashable : Any]) {
        Apphud.addAttribution(data: conversionInfo, from: .appsFlyer, identifer: AppsFlyerLib.shared().getAppsFlyerUID()) { _ in }
    }
    
    func onConversionDataFail(_ error: Error) {
        Apphud.addAttribution(data: ["error" : error.localizedDescription], from: .appsFlyer, identifer: AppsFlyerLib.shared().getAppsFlyerUID()) { _ in }
    }
    
    var window: UIWindow?
    
    func application(_ application: UIApplication, didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?) -> Bool {
        // Override point for customization after application launch.
        
        // Setup Facebook
        ApplicationDelegate.shared.application(application, didFinishLaunchingWithOptions: launchOptions)
        setupFacebook(launchOptions: launchOptions)
        //
        
        // Setup Apphud
        Apphud.start(apiKey: "app_q1opvXjFE1ADcjrGnvNnFVYu1tzh6d")
        Apphud.setDelegate(self)
        Apphud.setUIDelegate(self)
        //
        
        // Setup AppsFlyer
        AppsFlyerLib.shared().appsFlyerDevKey = "12345"
        AppsFlyerLib.shared().appleAppID = "0123456789"
        AppsFlyerLib.shared().delegate = self
        //
        
        // Setup Amplitude
        Amplitude.instance().initializeApiKey("API_KEY")
        Amplitude.instance().setUserId(Apphud.userID())
        Amplitude.instance().logEvent("sdk_init")
        //
        
        // Setup Branch
        Branch.getInstance().initSession(launchOptions: launchOptions) { (params, error) in
            // print(params as? [String: AnyObject] ?? {})
            // Access and use deep link data here (nav to page, display content, etc.)
        }
        //
        
        // Register Remote Notifications
        registerForNotifications()
        //
        
        return true
    }
    
    func application(_ app: UIApplication, open url: URL, options: [UIApplication.OpenURLOptionsKey : Any] = [:]) -> Bool {
        // Branch
        Branch.getInstance().application(app, open: url, options: options)
        return true
    }
    
    func setupFacebook(launchOptions: [UIApplication.LaunchOptionsKey: Any]?) {
        // Facebook
        Settings.shared.isAdvertiserTrackingEnabled = true
    }
    
    func application(_ application: UIApplication, continue userActivity: NSUserActivity, restorationHandler: @escaping ([UIUserActivityRestoring]?) -> Void) -> Bool {
        // AppsFlyer
        AppsFlyerLib.shared().continue(userActivity, restorationHandler: nil)
        
        // Branch
        Branch.getInstance().continue(userActivity)
        
        return true
    }
    
    func applicationDidBecomeActive(_ application: UIApplication) {
        // Facebook
        AppEvents.shared.activateApp()
        
        // AppsFlyer
        AppsFlyerLib.shared().start()
    }
    
    func registerForNotifications() {
        // Setup remote notifications
        UNUserNotificationCenter.current().delegate = self
        UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .badge, .sound]) { (_, _) in }
        UIApplication.shared.registerForRemoteNotifications()
    }
    
    // MARK: - Remote notifications delegate methods
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
            return .overFullScreen
        } else {
            return .pageSheet
        }
    }
}

extension AppDelegate: ApphudDelegate {
    
    func apphudDidChangeUserID(_ userID: String) {
        // Match users Apphud and Amplitude
        Amplitude.instance().setUserId(userID)
    }
    
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
