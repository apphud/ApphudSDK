//
//  IAPManager.swift
//  http://apphud.com
//
//  Created by Apphud on 04/01/2019.
//  Copyright © 2019 Softeam Inc. All rights reserved.
//

import UIKit
import StoreKit

public typealias SuccessBlock = () -> Void
public typealias FailureBlock = (Error?) -> Void

let IAP_PRODUCTS_DID_LOAD_NOTIFICATION = Notification.Name("IAP_PRODUCTS_DID_LOAD_NOTIFICATION")

class IAPManager : NSObject{
    
    @objc static let shared = IAPManager()
    @objc private(set) var products : Array<SKProduct>?
    
    private override init(){}
    private var productIds : Set<String> = []
    
    private var successBlock : SuccessBlock?
    private var failureBlock : FailureBlock?
    
    private var refreshSubscriptionSuccessBlock : SuccessBlock?
    private var refreshSubscriptionFailureBlock : FailureBlock?
    
    // MARK:- Main methods
    
    @objc func startWith(arrayOfIds : Set<String>!){
        SKPaymentQueue.default().add(self)
        self.productIds = arrayOfIds
        loadProducts()
    }
    
    func expirationDateFor(_ identifier : String) -> Date?{
        return UserDefaults.standard.object(forKey: identifier) as? Date
    }
    
    func purchaseProduct(product : SKProduct, success: @escaping SuccessBlock, failure: @escaping FailureBlock){
        
        guard SKPaymentQueue.canMakePayments() else {
            return
        }
        guard SKPaymentQueue.default().transactions.last?.transactionState != .purchasing else {
            return
        }        
        self.successBlock = success
        self.failureBlock = failure
        let payment = SKPayment(product: product)
        SKPaymentQueue.default().add(payment)
    }
    
    func restorePurchases(success: @escaping SuccessBlock, failure: @escaping FailureBlock){
        self.successBlock = success
        self.failureBlock = failure
        SKPaymentQueue.default().restoreCompletedTransactions()
    }
    
    /*
     Private method. Should not be called directly. Call refreshSubscriptionsStatus instead. 
     */
    private func refreshReceipt(){
        let request = SKReceiptRefreshRequest(receiptProperties: nil)
        request.delegate = self
        request.start()
    }
    
    private func loadProducts(){
        let request = SKProductsRequest.init(productIdentifiers: productIds)
        request.delegate = self
        request.start()
    }
    
    private func cleanUpRefeshReceiptBlocks(){
        self.refreshSubscriptionSuccessBlock = nil
        self.refreshSubscriptionFailureBlock = nil
    }
}

// MARK:- SKProducts Request Delegate

extension IAPManager: SKProductsRequestDelegate {
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {                
        products = response.products
        DispatchQueue.main.async {
            NotificationCenter.default.post(name: IAP_PRODUCTS_DID_LOAD_NOTIFICATION, object: nil)
        }
    }
}

// MARK:- SKPayment Transaction Observer

extension IAPManager: SKPaymentTransactionObserver {
    
    public func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        
        for transaction in transactions {
            switch (transaction.transactionState) {
            case .purchased:
                SKPaymentQueue.default().finishTransaction(transaction)
                notifyIsPurchased(transaction: transaction)
                break
            case .failed:
                SKPaymentQueue.default().finishTransaction(transaction)
                print("purchase error : \(transaction.error?.localizedDescription ?? "")")
                self.failureBlock?(transaction.error)
                cleanUp()
                break
            case .restored:
                SKPaymentQueue.default().finishTransaction(transaction)
                notifyIsPurchased(transaction: transaction)
                break
            case .deferred, .purchasing:
                break
            default:
                break
            }
        }
    }
    
    private func notifyIsPurchased(transaction: SKPaymentTransaction) {
        
        self.successBlock?()
        self.cleanUp()
        
//        refreshSubscriptionsStatus(callback: { 
//            self.successBlock?()
//            self.cleanUp()
//        }) { (error) in            
//            // couldn't verify receipt
//            self.failureBlock?(error)
//            self.cleanUp()
//        }
    }
    
    func cleanUp(){
        self.successBlock = nil
        self.failureBlock = nil
    }
}
