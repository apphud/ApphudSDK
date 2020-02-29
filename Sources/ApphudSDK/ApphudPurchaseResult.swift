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
     Standard in-app purchase (non-consumable, consumable or non-renewing subscription)
     */
    @objc public let nonRenewingPurchase: ApphudNonRenewingPurchase?
    
    /**
     Transaction from StoreKit
     */
    @objc public let transaction: SKPaymentTransaction?
    
    /**
     Error from StoreKit or from HTTP Session
     */
    let error: Error?
    
    // MARK:- Private methods
    
    init(_ subscription: ApphudSubscription?, _ purchase: ApphudNonRenewingPurchase?, _ transaction: SKPaymentTransaction?, _ error: Error?) {
        self.subscription = subscription
        self.nonRenewingPurchase = purchase
        self.transaction = transaction
        self.error = error
    }
}
