//
//  ApphudStoreKitFetcher.swift
//  subscriptionstest
//
//  Created by ren6 on 01/07/2019.
//  Copyright © 2019 apphud. All rights reserved.
//

import Foundation
import StoreKit

internal typealias ApphudStoreKitProductsCallback = ([SKProduct]) -> Void
internal typealias ApphudTransactionCallback = (SKPaymentTransaction, Error?) -> Void

public let ApphudWillFinishTransactionNotification = Notification.Name(rawValue: "ApphudWillFinishTransactionNotification")
public let ApphudDidFinishTransactionNotification = Notification.Name(rawValue: "ApphudDidFinishTransactionNotification")

@available(iOS 11.2, *)
internal class ApphudStoreKitWrapper: NSObject, SKPaymentTransactionObserver, SKRequestDelegate {
    static var shared = ApphudStoreKitWrapper()

    internal var products = [SKProduct]()

    fileprivate let fetcher = ApphudProductsFetcher()
    fileprivate let receiptSubmitProductFetcher = ApphudProductsFetcher()

    private var refreshReceiptCallback: (() -> Void)?
    private var paymentCallback: ApphudTransactionCallback?
    private var purchasingProductID: String?
    private weak var purchasingPayment: SKPayment?
    internal var customProductsFetchedBlock: ApphudStoreKitProductsCallback?

    private var refreshRequest: SKReceiptRefreshRequest?

    func setupObserver() {
        SKPaymentQueue.default().add(self)
    }

    func refreshReceipt(_ callback: (() -> Void)?) {
        refreshReceiptCallback = callback
        refreshRequest = SKReceiptRefreshRequest()
        refreshRequest?.delegate = self
        refreshRequest?.start()
    }

    func fetchProducts(identifiers: Set<String>, callback: @escaping ApphudStoreKitProductsCallback) {
        fetcher.fetchStoreKitProducts(identifiers: identifiers) { (products) in
            self.products.append(contentsOf: products)
            callback(products)
            NotificationCenter.default.post(name: Apphud.didFetchProductsNotification(), object: self.products)
            ApphudInternal.shared.delegate?.apphudDidFetchStoreKitProducts?(self.products)
            self.customProductsFetchedBlock?(self.products)
            self.customProductsFetchedBlock = nil
        }
    }

    func fetchReceiptSubmitProduct(productId: String, callback: @escaping (SKProduct?) -> Void) {
        receiptSubmitProductFetcher.fetchStoreKitProducts(identifiers: Set([productId])) { (products) in
            callback(products.first)
        }
    }

    func purchase(product: SKProduct, callback: @escaping ApphudTransactionCallback) {
        ApphudUtils.shared.storeKitObserverMode = false
        let payment = SKMutablePayment(product: product)
        purchase(payment: payment, callback: callback)
    }

    @available(iOS 12.2, *)
    func purchase(product: SKProduct, discount: SKPaymentDiscount, callback: @escaping ApphudTransactionCallback) {
        ApphudUtils.shared.storeKitObserverMode = false
        let payment = SKMutablePayment(product: product)
        payment.paymentDiscount = discount
        purchase(payment: payment, callback: callback)
    }

    func purchase(payment: SKMutablePayment, callback: @escaping ApphudTransactionCallback) {
        finishCompletedTransactions(for: payment.productIdentifier)
        payment.applicationUsername = ""
        paymentCallback = callback
        purchasingProductID = payment.productIdentifier
        purchasingPayment = payment
        apphudLog("Starting payment for \(payment.productIdentifier), transactions in queue: \(SKPaymentQueue.default().transactions)")
        SKPaymentQueue.default().add(payment)
    }

    // MARK: - SKPaymentTransactionObserver

    func paymentQueue(_ queue: SKPaymentQueue, updatedTransactions transactions: [SKPaymentTransaction]) {
        DispatchQueue.main.async {
            for trx in transactions {
                switch trx.transactionState {
                case .purchasing:
                    if self.purchasingProductID == nil && ApphudUtils.shared.storeKitObserverMode == false {
                        apphudLog("Seems like Observer Mode is False however purchase is not being made through Apphud SDK. Please make sure you set ObserverMode to True when initialising Apphud SDK. As for now, force enabling observer mode..", logLevel: .off)
                        ApphudUtils.shared.storeKitObserverMode = true
                    }
                case .purchased, .failed:
                    self.handleTransactionIfStarted(trx)
                case .restored:
                    /*
                     Always handle restored transactions by sending App Store Receipt to Apphud.
                     Will not finish transaction, because we didn't start it. Developer should finish transaction manually.
                     */
                    ApphudInternal.shared.submitReceiptRestore(allowsReceiptRefresh: true)
                    if !ApphudUtils.shared.storeKitObserverMode {
                        // force finish transaction
                        self.finishTransaction(trx)
                    }
                default:
                    break
                }
            }
        }
    }

    private func handleTransactionIfStarted(_ transaction: SKPaymentTransaction) {

        if transaction.payment == purchasingPayment {
            apphudLog("handle transaction started by Apphud SDK method", forceDisplay: false)
        }

        if transaction.payment.productIdentifier == self.purchasingProductID {
            self.purchasingProductID = nil
            if self.paymentCallback != nil {
                self.paymentCallback?(transaction, nil)
            } else {
                finishTransaction(transaction)
            }
            self.paymentCallback = nil
            self.purchasingPayment = nil
        } else {
            if transaction.transactionState == .purchased || transaction.failedWithUnknownReason {
                ApphudInternal.shared.submitReceiptAutomaticPurchaseTracking(transaction: transaction)
            }
            if !ApphudUtils.shared.storeKitObserverMode {
                // force finish transaction
                finishTransaction(transaction)
            }
        }
    }

    private func finishCompletedTransactions(for productIdentifier: String) {
        SKPaymentQueue.default().transactions.filter { $0.payment.productIdentifier == productIdentifier && $0.finishable }.forEach { transaction in finishTransaction(transaction) }
    }

    internal func finishTransaction(_ transaction: SKPaymentTransaction) {
        apphudLog("Finish Transaction: \(transaction.payment.productIdentifier), state: \(transaction.transactionState.rawValue), id: \(transaction.transactionIdentifier ?? "")")
        NotificationCenter.default.post(name: ApphudWillFinishTransactionNotification, object: transaction)
        SKPaymentQueue.default().finishTransaction(transaction)
        NotificationCenter.default.post(name: ApphudDidFinishTransactionNotification, object: transaction)
    }

    #if os(iOS) && !targetEnvironment(macCatalyst)
    func paymentQueue(_ queue: SKPaymentQueue, shouldAddStorePayment payment: SKPayment, for product: SKProduct) -> Bool {

        DispatchQueue.main.async {
            if let callback = ApphudInternal.shared.delegate?.apphudShouldStartAppStoreDirectPurchase?(product) {
                Apphud.purchase(product, callback: callback)
            }
        }

        return false
    }
    #endif

    // MARK: - SKRequestDelegate

    func requestDidFinish(_ request: SKRequest) {
        if request is SKReceiptRefreshRequest {
            DispatchQueue.main.async {
                if self.refreshReceiptCallback != nil {
                    self.refreshReceiptCallback?()
                    self.refreshReceiptCallback = nil
                } else {
                    ApphudInternal.shared.submitReceiptRestore(allowsReceiptRefresh: false)
                }
                self.refreshRequest = nil
            }
        }
    }

    /**
     Try to restore even if refresh receipt failed. Current receipt (unrefreshed) will be sent instead.
     */
    func request(_ request: SKRequest, didFailWithError error: Error) {
        if request is SKReceiptRefreshRequest {
            DispatchQueue.main.async {
                if self.refreshReceiptCallback != nil {
                    self.refreshReceiptCallback?()
                    self.refreshReceiptCallback = nil
                } else {
                    ApphudInternal.shared.submitReceiptRestore(allowsReceiptRefresh: false)
                }
                self.refreshRequest = nil
            }
        }
    }
}

/*
 This class will be extended in the future.
 */
private class ApphudProductsFetcher: NSObject, SKProductsRequestDelegate {
    private var callback: ApphudStoreKitProductsCallback?

    private var productsRequest: SKProductsRequest?

    func fetchStoreKitProducts(identifiers: Set<String>, callback : @escaping ApphudStoreKitProductsCallback) {
        self.callback = callback
        productsRequest = SKProductsRequest(productIdentifiers: identifiers)
        productsRequest?.delegate = self
        productsRequest?.start()
    }

    public func productsRequest(_ request: SKProductsRequest, didReceive response: SKProductsResponse) {
        DispatchQueue.main.async {
            self.callback?(response.products)
            if response.invalidProductIdentifiers.count > 0 {
                apphudLog("Failed to load SKProducts from the App Store, because product identifiers are invalid:\n \(response.invalidProductIdentifiers)", forceDisplay: true)
            }
            self.callback = nil
            self.productsRequest = nil
        }
    }

    func request(_ request: SKRequest, didFailWithError error: Error) {
        DispatchQueue.main.async {
            apphudLog("Failed to load SKProducts from the App Store, error: \(error)", forceDisplay: true)
            self.callback?([])
            self.callback = nil
            self.productsRequest = nil
        }
    }
}

extension SKPaymentTransaction {
    var failedWithUnknownReason: Bool {
        transactionState == .failed && (error is SKError) && (error as? SKError)?.code == SKError.Code.unknown
    }

    var finishable: Bool {
        switch transactionState {
        case .purchasing:
            return false
        case .deferred, .failed, .purchased, .restored:
            return true
        @unknown default:
            return false
        }
    }
}
