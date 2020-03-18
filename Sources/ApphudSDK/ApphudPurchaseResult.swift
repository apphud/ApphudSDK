//
//  ApphudPurchaseResult.swift
//  apphud
//
//  Created by Renat on 23.02.2020.
//  Copyright © 2020 softeam. All rights reserved.
//

import Foundation
import StoreKit

/**
 General class that is returned in purchase block.
 
 Using class instead of struct in order to support Objective-C
*/ 

public class ApphudPurchaseResult: NSObject {
    
    /**
     Autorenewable subscription object. May be nil if error occurred or if non renewing product purchased instead.
     */
    @objc public let subscription: ApphudSubscription?
    
    /**
     Standard in-app purchase (non-consumable, consumable or non-renewing subscription) object. May be nil if error occurred or if auto-renewable subscription purchased instead.
     */
    @objc public let nonRenewingPurchase: ApphudNonRenewingPurchase?
    
    /**
     Transaction from StoreKit. May be nil, if no transaction made. For example, if couldn't sign promo offer or couldn't get App Store receipt.
     */
    @objc public let transaction: SKPaymentTransaction?
    
    /**
     This error can be of three types. Check for error class.
     - `SKError` from StoreKit with `SKErrorDomain` codes. This is a system error when purchasing transaction.
     - `NSError` from HTTP Client with `NSURLErrorDomain` codes. This is a network/server issue when uploading receipt to Apphud.
     - Custom `ApphudError` without codes. For example, if couldn't sign promo offer or couldn't get App Store receipt.
     */
    public let error: Error?
    
    // MARK:- Private methods
    
    init(_ subscription: ApphudSubscription?, _ purchase: ApphudNonRenewingPurchase?, _ transaction: SKPaymentTransaction?, _ error: Error?) {
        self.subscription = subscription
        self.nonRenewingPurchase = purchase
        self.transaction = transaction
        self.error = error
    }
}
