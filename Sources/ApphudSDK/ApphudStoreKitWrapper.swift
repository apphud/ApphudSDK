//
//  ApphudStoreKitFetcher.swift
//  subscriptionstest
//
//  Created by Renat on 01/07/2019.
//  Copyright © 2019 apphud. All rights reserved.
//

import Foundation
import StoreKit

internal typealias ApphudStoreKitProductsCallback = ([SKProduct]) -> Void

@available(iOS 11.2, *)
internal class ApphudStoreKitWrapper: NSObject, SKPaymentTransactionObserver, SKRequestDelegate{
    static var shared = ApphudStoreKitWrapper()
    
    internal var products = [SKProduct]()
    
    fileprivate let fetcher = ApphudProductsFetcher()
    
    private var paymentCallback : ((SKPaymentTransaction) -> Void)?
    private var purchasingProductID : String?
    
    func setupObserver(){
        SKPaymentQueue.default().add(self)
    }
    
    func refreshReceipt(){
        let request = SKReceiptRefreshRequest()
        request.delegate = self
        request.start()
    }
    
    func fetchProducts(identifiers: Set<String>, callback: @escaping ApphudStoreKitProductsCallback) {
        fetcher.fetchStoreKitProducts(identifiers: identifiers) { (products) in
            self.products.append(contentsOf: products)
            callback(products)
            NotificationCenter.default.post(name: Apphud.didFetchProductsNotification(), object: self.products)
            ApphudInternal.shared.delegate?.apphudDidFetchStoreKitProducts?(products)
        }
    }
    
    func purchase(product: SKProduct, callback: @escaping (SKPaymentTransaction) -> Void){
        let payment = SKMutablePayment(product: product)
        purchase(payment: payment, callback: callback)
    }
    
    @available(iOS 12.2, *)
    func purchase(product: SKProduct, discount: SKPaymentDiscount, callback: @escaping (SKPaymentTransaction) -> Void){
        let payment = SKMutablePayment(product: product)
        payment.paymentDiscount = discount
        purchase(payment: payment, callback: callback)
    }
    
    func purchase(payment : SKMutablePayment, callback: @escaping (SKPaymentTransaction) -> Void){
        
        guard SKPaymentQueue.canMakePayments() else {
            return
        }
        
        guard SKPaymentQueue.default().transactions.last?.transactionState != .purchasing else {
            return
        } 
        
        if self.purchasingProductID != nil {return}
        
        payment.applicationUsername = ""
        self.paymentCallback = callback
        self.purchasingProductID = payment.productIdentifier
        SKPaymentQueue.default().add(payment)
    }
    
    // MARK:- SKPaymentTransactionObserver
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        DispatchQueue.main.async {
            for trx in transactions {
                
                switch (trx.transactionState) {
                case .purchased, .failed:
                    self.handleTransactionIfStarted(trx)
                    break
                case .restored:
                    /*
                     Always handle restored transactions by sending App Store Receipt to Apphud.
                     Will not finish transaction, because we didn't start it. Developer should finish transaction manually.
                     */
                    ApphudInternal.shared.submitReceiptRestore(allowsReceiptRefresh: true)
                    break
                default:
                    break
                }
            }
        }
    }    
    
    private func handleTransactionIfStarted(_ transaction : SKPaymentTransaction) {
        if transaction.payment.productIdentifier == self.purchasingProductID {
            self.purchasingProductID = nil
            if self.paymentCallback != nil {
                self.paymentCallback?(transaction)
            } else {
                // Finish transaction because Apphud SDK started it.
                SKPaymentQueue.default().finishTransaction(transaction)
            }
            self.paymentCallback = nil
        } else {
            // we didn't start this transaction, just submit receipt
            if transaction.transactionState == .purchased {
                ApphudInternal.shared.submitReceiptAutomaticPurchaseTracking()
            }
        }
    }
    
    // MARK:- SKRequestDelegate
    
    func requestDidFinish(_ request: SKRequest) {
        if request is SKReceiptRefreshRequest {
            DispatchQueue.main.async {
                ApphudInternal.shared.submitReceiptRestore(allowsReceiptRefresh: false)                
            }
        }
    }
    
    /**
     Try to restore even if refresh receipt failed. Current receipt (unrefreshed) will be sent instead.
     */
    func request(_ request: SKRequest, didFailWithError error: Error) {
        if request is SKReceiptRefreshRequest {
            ApphudInternal.shared.submitReceiptRestore(allowsReceiptRefresh: false)
        }
    }
}

/*
 This class will be extended in the future.
 */
private class ApphudProductsFetcher : NSObject, SKProductsRequestDelegate{
    private var callback : ApphudStoreKitProductsCallback?
    
    func fetchStoreKitProducts(identifiers : Set<String>, callback : @escaping ApphudStoreKitProductsCallback) {
        self.callback = callback        
        let request = SKProductsRequest(productIdentifiers: identifiers)
        request.delegate = self
        request.start()
    }
    
    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.callback?(response.products)
            self.callback = nil            
        }
    }
}
