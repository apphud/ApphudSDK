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
    let subscription: ApphudSubscription?
    
    /**
        Non consumable, consumable purchase or nonrenewing subscription
     */
    let purchase: ApphudPurchase?
    
    /**
     Error from StoreKit
     */
    let error: Error?
    
    /**
     Transaction from StoreKit. May be nil in some cases.
     */
    let transaction: SKPaymentTransaction?
    
    init(_ subscription: ApphudSubscription?, _ purchase: ApphudPurchase?, _ transaction: SKPaymentTransaction?, _ error: Error?) {
        self.subscription = subscription
        self.purchase = purchase
        self.transaction = transaction
        self.error = error
    }
}
