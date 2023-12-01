//
//  ApphudUIDelegate.swift
//  ApphudSDK
//
//  Created by ren6 on 01/07/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import StoreKit
import Foundation
#if canImport(UIKit)
import UIKit
#endif

/**
 These are three types of actions that are returned in `apphudScreenDismissAction(screenName: String, controller: UIViewController)` delegate method
 */
@objc public enum ApphudScreenDismissAction: Int {

    // Displays "Thank you for feedback" or "Answer sent" alert message and dismisses
    case thankAndClose

    // Just dismisses view controller
    case closeOnly

    // Does nothing, in this case you can push your own view controller into hierarchy, use `navigationController` property of `controller` variable.
    case none
}

/**
 A public protocol that provides access to Apphud's main public methods, describing the behavior of the Rules state and custom Rules view presentation
 */
@MainActor @objc public protocol ApphudUIDelegate {
    /**
        You can return `false` to ignore this rule. You should only do this if you want to handle your rules by yourself. Default implementation is `true`.
     */
    @objc optional func apphudShouldPerformRule(rule: ApphudRule) -> Bool

    /**
        You can return `false` to this delegate method if you want to delay Apphud Screen presentation.
     
        Controller will be kept in memory until you present it via `Apphud.showPendingScreen()` method. If you don't want to show screen at all, you should check `apphudShouldPerformRule` delegate method.
     */
    @objc optional func apphudShouldShowScreen(screenName: String) -> Bool

    #if os(iOS)
    /**
        Return `UIViewController` instance from which you want to present given Apphud controller. If you don't implement this method, then top visible viewcontroller from key window will be used.
     
        __Note__: This delegate method is recommended for implementation when you have multiple windows in your app, because Apphud SDK may have issues while presenting screens in this case.
     */
    @objc optional func apphudParentViewController(controller: UIViewController) -> UIViewController

    /**
     Pass your own modal presentation style to Apphud Screens. This is useful since iOS 13 presents in page sheet style by default.
     
     To get full screen style you should pass `.fullScreen` or `.overFullScreen`.
     */
    @objc optional func apphudScreenPresentationStyle(controller: UIViewController) -> UIModalPresentationStyle

    #endif
    /**
     Called when user tapped on purchase button in Apphud purchase screen.
    */
    @objc optional func apphudWillPurchase(product: SKProduct, offerID: String?, screenName: String)

    /**
     Called when user successfully purchased product in Apphud purchase screen.
    */
    @objc optional func apphudDidPurchase(product: SKProduct, offerID: String?, screenName: String)

    /**
     Called when purchase failed in Apphud purchase screen.
     
     See error code for details. For example, `.paymentCancelled` error code is when user canceled the purchase by himself.
    */
    @objc optional func apphudDidFailPurchase(product: SKProduct, offerID: String?, errorCode: SKError.Code, screenName: String)

    /**
     Called when screen succesfully loaded and is visible to user.
     */
    @objc optional func apphudScreenDidAppear(screenName: String)

    /**
     Called when screen is about to dismiss.
     */
    @objc optional func apphudScreenWillDismiss(screenName: String, error: Error?)

    #if os(iOS)
    /**
     Notifies that Apphud Screen did dismiss
    */
    @objc optional func apphudDidDismissScreen(controller: UIViewController)

    /**
     (New) Overrides action after survey option is selected or feeback sent is tapped. Default is "thankAndClose".
     This delegate method is only called if no other screen is selected as button action in Apphud Screens editor.
     You can return `noAction` value and use `navigationController` property of `controller` variable to push your own view controller into hierarchy.
     */
    @objc optional func apphudScreenDismissAction(screenName: String, controller: UIViewController) -> ApphudScreenDismissAction
    #endif

    /**
     (New) Called after survey answer is selected.
     */
    @objc optional func apphudDidSelectSurveyAnswer(question: String, answer: String, screenName: String)
}
