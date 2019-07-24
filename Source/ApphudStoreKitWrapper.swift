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

internal class ApphudStoreKitWrapper: NSObject, SKPaymentTransactionObserver, SKRequestDelegate{
    static var shared = ApphudStoreKitWrapper()
    
    internal var products = [SKProduct]()
    
    fileprivate let fetcher = ApphudProductsFetcher()
    
    func setupObserver(){
        SKPaymentQueue.default().add(self)
    }
    
    func refreshReceipt(){
        let request = SKReceiptRefreshRequest()
        request.delegate = self
        request.start()
    }
    
    fileprivate func loadedProduct(identifier : String) -> SKProduct? {
        return products.first(where: { $0.productIdentifier == identifier})
    }
    
    func fetchProducts(identifiers : Set<String>, callback : @escaping ApphudStoreKitProductsCallback) {
        fetcher.fetchStoreKitProducts(identifiers: identifiers) { (products) in
            self.products.append(contentsOf: products)
            callback(products)
        }
    }
    
    // MARK:- SKPaymentTransactionObserver
    
    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        /*
         if at least one transaction state is restored, then we should restore Apphud subscriptions for current device.
         Only restored transactions are handled at the moment. Developer should handle purchase process manually.
         */
        for trx in transactions {
            if trx.transactionState == .restored {
                ApphudInternal.shared.restore(allowsReceiptRefresh: true)
                break
            }
        }
    }    
    
    // MARK:- SKRequestDelegate
    
    func requestDidFinish(_ request: SKRequest) {
        if request is SKReceiptRefreshRequest {
            ApphudInternal.shared.restore(allowsReceiptRefresh: false)
        }
    }
    
    /**
     Try to restore even if refresh receipt failed. Current receipt (unrefreshed) will be sent instead.
     */
    func request(_ request: SKRequest, didFailWithError error: Error) {
        if request is SKReceiptRefreshRequest {
            ApphudInternal.shared.restore(allowsReceiptRefresh: false)
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
        self.callback?(response.products)
        self.callback = nil
    }
}
