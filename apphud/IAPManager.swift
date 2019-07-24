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
    
    private var sharedSecret = ""
    @objc static let shared = IAPManager()
    @objc private(set) var products : Array<SKProduct>?
    
    private override init(){}
    private var productIds : Set<String> = []
    
    private var successBlock : SuccessBlock?
    private var failureBlock : FailureBlock?
    
    private var refreshSubscriptionSuccessBlock : SuccessBlock?
    private var refreshSubscriptionFailureBlock : FailureBlock?
    
    // MARK:- Main methods
    
    @objc func startWith(arrayOfIds : Set<String>!, sharedSecret : String){
        SKPaymentQueue.default().add(self)
        self.sharedSecret = sharedSecret
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
    
//    /* It's the most simple way to send verify receipt request. Consider this code as for learning purposes. You shouldn't use current code in production apps.
//     This code doesn't handle errors.
//     */
//    func refreshSubscriptionsStatus(callback : @escaping SuccessBlock, failure : @escaping FailureBlock){
//        
//        self.refreshSubscriptionSuccessBlock = callback
//        self.refreshSubscriptionFailureBlock = failure
//        
//        guard let receiptUrl = Bundle.main.appStoreReceiptURL else {
//            refreshReceipt()
//            // do not call block in this case. It will be called inside after receipt refreshing finishes.
//            return
//        }
//        
//        #if DEBUG
//        let urlString = "https://sandbox.itunes.apple.com/verifyReceipt"
//        #else 
//        let urlString = "https://buy.itunes.apple.com/verifyReceipt"
//        #endif
//        let receiptData = try? Data(contentsOf: receiptUrl).base64EncodedString()
//        let requestData = ["receipt-data" : receiptData ?? "", "password" : self.sharedSecret, "exclude-old-transactions" : true] as [String : Any]
//        var request = URLRequest(url: URL(string: urlString)!)
//        request.httpMethod = "POST"
//        request.setValue("Application/json", forHTTPHeaderField: "Content-Type")
//        let httpBody = try? JSONSerialization.data(withJSONObject: requestData, options: [])
//        request.httpBody = httpBody
//        
//        URLSession.shared.dataTask(with: request)  { (data, response, error) in
//            DispatchQueue.main.async {
//                if data != nil {
//                    if let json = try? JSONSerialization.jsonObject(with: data!, options: .allowFragments){
//                        self.parseReceipt(json as! Dictionary<String, Any>)
//                        return
//                    }
//                } else {
//                    print("error validating receipt: \(error?.localizedDescription ?? "")")
//                }
//                self.refreshSubscriptionFailureBlock?(error)
//                self.cleanUpRefeshReceiptBlocks()                
//            }
//            }.resume()        
//    }
//    
//    /* It's the most simple way to get latest expiration date. Consider this code as for learning purposes. You shouldn't use current code in production apps.
//     This code doesn't handle errors or some situations like cancellation date.
//     */
//    private func parseReceipt(_ json : Dictionary<String, Any>) {
//        guard let receipts_array = json["latest_receipt_info"] as? [Dictionary<String, Any>] else {
//            self.refreshSubscriptionFailureBlock?(nil)
//            self.cleanUpRefeshReceiptBlocks()
//            return
//        }
//        for receipt in receipts_array {
//            let productID = receipt["product_id"] as! String 
//            let formatter = DateFormatter()
//            formatter.dateFormat = "yyyy-MM-dd HH:mm:ss VV"
//            if let date = formatter.date(from: receipt["expires_date"] as! String) {
//                if date > Date() {
//                    // do not save expired date to user defaults to avoid overwriting with expired date
//                    UserDefaults.standard.set(date, forKey: productID)
//                }
//            }
//        }
//        self.refreshSubscriptionSuccessBlock?()
//        self.cleanUpRefeshReceiptBlocks()
//    }
//    
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

// MARK:- SKReceipt Refresh Request Delegate
//
//extension IAPManager : SKRequestDelegate {
//    
//    func requestDidFinish(_ request: SKRequest) {
//        if request is SKReceiptRefreshRequest {
//            refreshSubscriptionsStatus(callback: self.successBlock ?? {}, failure: self.failureBlock ?? {_ in})
//        }
//    }
//    
//    func request(_ request: SKRequest, didFailWithError error: Error){
//        if request is SKReceiptRefreshRequest {
//            self.refreshSubscriptionFailureBlock?(error)
//            self.cleanUpRefeshReceiptBlocks()            
//        }
//        print("error: \(error.localizedDescription)")
//    }
//}

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
