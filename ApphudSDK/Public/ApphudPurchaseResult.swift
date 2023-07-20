//
//  ApphudPurchaseResult.swift
//  Apphud, Inc
//
//  Created by ren6 on 23.02.2020.
//  Copyright © 2020 Apphud Inc. All rights reserved.
//

import Foundation
import StoreKit

/**
 General class that is returned in purchase block.
 
 Using class instead of struct in order to support Objective-C
*/ 
public class ApphudPurchaseResult: NSObject {

    /**
     Autorenewable subscription object. May be nil if error occurred or if non renewing product purchased instead. Nil if `purchaseWithoutValidation` method called.
     */
    public let subscription: ApphudSubscription?

    /**
     Standard in-app purchase (non-consumable, consumable or non-renewing subscription) object. May be nil if error occurred or if auto-renewable subscription purchased instead. Nil if `purchaseWithoutValidation` method called.
     */
    public let nonRenewingPurchase: ApphudNonRenewingPurchase?

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
    @objc public let error: Error?

    public var success: Bool {
        error == nil
    }

    // MARK: - Private methods

    init(_ subscription: ApphudSubscription?, _ purchase: ApphudNonRenewingPurchase?, _ transaction: SKPaymentTransaction?, _ error: Error?) {
        self.subscription = subscription
        self.nonRenewingPurchase = purchase
        self.transaction = transaction
        self.error = error
    }

    public override var description: String {
        """
            ApphudPurchaseResult:
        \ntransaction_id = \(transaction?.transactionIdentifier ?? "")
        \nproduct_id = \(transaction?.payment.productIdentifier ?? "")
        \nsubscription status = \( subscription != nil ? subscription!.isActive().description : "nil")
        \nnon renewing purchase status = \( nonRenewingPurchase != nil ? nonRenewingPurchase!.isActive().description : "nil")
        \nerror = \(error?.localizedDescription ?? "nil")
        """
    }
}
