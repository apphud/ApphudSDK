//
//  ViewController.swift
//  Apphud, Inc
//
//  Created by ren6 on 11/06/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import UIKit
import StoreKit
import ApphudSDK

let cellID = "cell"

class ViewController: UITableViewController {

    var products = [SKProduct]()

    override func viewDidLoad() {
        super.viewDidLoad()

        Apphud.setDelegate(self)
        Apphud.setUIDelegate(self)

        reload()

        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Restore", style: .done, target: self, action: #selector(restore))

        if Apphud.products() == nil {
            Apphud.productsDidFetchCallback { (products) in
                self.products = products
                self.reload()
            }
        } else {
            self.products = Apphud.products()!
        }
    }

    @objc func restore() {
        Apphud.restorePurchases { _, _, _ in
            self.reload()
        }
    }

    @objc func reload() {
        tableView.reloadData()
    }

    // MARK: - TableView Delegate methods

    override func numberOfSections(in tableView: UITableView) -> Int {
        1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        products.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {

        let cell = tableView.dequeueReusableCell(withIdentifier: cellID, for: indexPath)
        let product = products[indexPath.item]

        if let text = product.fullSubscriptionInfoString() {
            cell.textLabel?.text = text
        } else {
            cell.textLabel?.text = product.localizedPriceFrom(price: product.price)
        }

        if let subscription = Apphud.subscriptions()?.first(where: {$0.productId == product.productIdentifier}) {

            cell.detailTextLabel?.text = subscription.expiresDate.description(with: Locale.current) + "\nState: \(subscription.status.toStringDuplicate())\nIntroductory used:\(subscription.isIntroductoryActivated)".uppercased()

        } else if let purchase = Apphud.nonRenewingPurchases()?.first(where: {$0.productId == product.productIdentifier}) {
            cell.detailTextLabel?.text = "\(purchase.productId). Last Purchased at: \(purchase.purchasedAt)"
            print("purchase: \(purchase.productId) is active: \(purchase.isActive())")
        } else {
            cell.detailTextLabel?.text = "\(product.productIdentifier): not active"
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {

        tableView.deselectRow(at: indexPath, animated: true)

        let product = products[indexPath.item]

        if #available(iOS 12.2, *) {
            if product.discounts.count > 0 && (Apphud.subscriptions()?.first(where: {$0.productId == product.productIdentifier}) != nil) {
                // purchase promo offer                
                showPromoOffersAlert(product: product)
            } else {
                purchaseProduct(product: product)
            }
        } else {
            purchaseProduct(product: product)
        }
    }

    @available(iOS 12.2, *)
    func showPromoOffersAlert(product: SKProduct) {

        let controller = UIAlertController(title: "You already have subscription for this product", message: "would you like to activate promo offer?", preferredStyle: .alert)

        for discount in product.discounts {
            controller.addAction(UIAlertAction(title: "Purchase Promo: \(discount.identifier!)", style: .default, handler: { _ in
                self.purchaseProduct(product: product, promoID: discount.identifier!)
            }))
        }

        controller.addAction(UIAlertAction(title: "Purchase Product As Usual", style: .destructive, handler: { _ in
            self.purchaseProduct(product: product)
        }))

        controller.addAction(UIAlertAction(title: "Cancel", style: .cancel, handler: nil))
        present(controller, animated: true, completion: nil)
    }

    @available(iOS 12.2, *)
    func purchaseProduct(product: SKProduct, promoID: String) {
        Apphud.purchasePromo(product, discountID: promoID) { (_) in
            self.reload()
        }
    }

    func purchaseProduct(product: SKProduct) {
        Apphud.purchase(product) { result in
            if result.error != nil {
                print("Purchase error: \(result.error?.localizedDescription ?? "")")
            } else {
                print("Purchase result: \(result.transaction?.transactionState.rawValue), trx_id: \(result.transaction?.transactionIdentifier)")
            }

            self.reload()
        }
    }
}

extension ViewController: ApphudDelegate {

    func apphudDidChangeUserID(_ userID: String) {
        print("new apphud user id: \(userID)")
    }

    func apphudDidFetchStoreKitProducts(_ products: [SKProduct]) {
        print("apphudDidFetchStoreKitProducts")
     //   self.products = products
        self.reload()
    }

    func apphudSubscriptionsUpdated(_ subscriptions: [ApphudSubscription]) {
        self.reload()
        print("apphudSubscriptionsUpdated")
    }

    func apphudNonRenewingPurchasesUpdated(_ purchases: [ApphudNonRenewingPurchase]) {
        print("non renewing purchases updated")
    }

    func apphudShouldStartAppStoreDirectPurchase(_ product: SKProduct) -> ((ApphudPurchaseResult) -> Void)? {
        let callback: ((ApphudPurchaseResult) -> Void) = { result in
            // handle ApphudPurchaseResult
            self.reload()
        }
        return callback
    }
}

extension ViewController: ApphudUIDelegate {

    func apphudShouldPerformRule(rule: ApphudRule) -> Bool {
        return true
    }

    func apphudShouldShowScreen(screenName: String) -> Bool {
        return true
    }

    func apphudScreenPresentationStyle(controller: UIViewController) -> UIModalPresentationStyle {
        if UIDevice.current.userInterfaceIdiom == .pad {
            return .pageSheet
        } else {
            return .fullScreen
        }
    }

    func apphudDidDismissScreen(controller: UIViewController) {
        print("did dismiss screen")
    }

    func apphudDidPurchase(product: SKProduct, offerID: String?, screenName: String) {
        print("did purchase \(product.productIdentifier), offer: \(offerID ?? ""), screenName: \(screenName)")
    }

    func apphudDidFailPurchase(product: SKProduct, offerID: String?, errorCode: SKError.Code, screenName: String) {
        print("did fail purchase \(product.productIdentifier), offer: \(offerID ?? ""), screenName: \(screenName), errorCode:\(errorCode.rawValue)")
    }

    func apphudWillPurchase(product: SKProduct, offerID: String?, screenName: String) {
        print("will purchase \(product.productIdentifier), offer: \(offerID ?? ""), screenName: \(screenName)")
    }
}
