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
     Autorenewable subscription
     */
    @objc public let subscription: ApphudSubscription?
    
    /**
        Non consumable, consumable purchase or nonrenewing subscription
     */
    @objc public let nonSubscriptionPurchase: ApphudNonSubscriptionPurchase?
    
    /**
     Transaction from StoreKit. May be nil in some cases.
     */
    @objc public let transaction: SKPaymentTransaction?
    
    /**
     Error from StoreKit
     */
    let error: Error?
    
    // MARK:- Private methods
    
    init(_ subscription: ApphudSubscription?, _ purchase: ApphudNonSubscriptionPurchase?, _ transaction: SKPaymentTransaction?, _ error: Error?) {
        self.subscription = subscription
        self.nonSubscriptionPurchase = purchase
        self.transaction = transaction
        self.error = error
    }
}
