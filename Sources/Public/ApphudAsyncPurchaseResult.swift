//
//  ApphudAsyncPurchaseResult.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 26.01.2023.
//

import Foundation
import StoreKit

@available(watchOSApplicationExtension 8.0, *)
@available(iOS 15.0, macOS 12.0, tvOS 15.0, *)
public struct ApphudAsyncPurchaseResult {

    /**
     Autorenewable subscription object. May be nil if error occurred or if non renewing product purchased instead. Nil if `purchaseWithoutValidation` method called.
     */
    public let subscription: ApphudSubscription?

    /**
     Standard in-app purchase (non-consumable, consumable or non-renewing subscription) object. May be nil if error occurred or if auto-renewable subscription purchased instead. Nil if `purchaseWithoutValidation` method called.
     */
    public let nonRenewingPurchase: ApphudNonRenewingPurchase?

    /**
     Transaction from modern StoreKit. A transaction represents a successful in-app purchase.
     */
    public let transaction: Transaction?

    /**
     This error can be of three types. Check for error class.
     - `SKError` from StoreKit with `SKErrorDomain` codes. This is a system error when purchasing transaction.
     - `NSError` from HTTP Client with `NSURLErrorDomain` codes. This is a network/server issue when uploading receipt to Apphud.
     - Custom `ApphudError` without codes. For example, if couldn't sign promo offer or couldn't get App Store receipt.
     */
    public let error: Error?

    /**
     True when the purchase is awaiting approval (Ask to Buy / Strong Customer
     Authentication). The transaction will be delivered later via `Transaction.updates`
     once approved; no error is reported in this case.
     */
    public let isPending: Bool

    public var success: Bool {
        transaction != nil
    }

    internal init(subscription: ApphudSubscription?, nonRenewingPurchase: ApphudNonRenewingPurchase?, transaction: Transaction?, error: Error?, isPending: Bool = false) {
        self.subscription = subscription
        self.nonRenewingPurchase = nonRenewingPurchase
        self.transaction = transaction
        self.error = error
        self.isPending = isPending
    }
}
