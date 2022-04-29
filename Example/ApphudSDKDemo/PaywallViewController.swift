//
//  PaywallViewController.swift
//  ApphudSDKDemo
//
//  Created by Валерий Левшин on 15.06.2021.
//  Copyright © 2021 softeam. All rights reserved.
//

import UIKit
import ApphudSDK

class PaywallViewController: UIViewController {

    let currentPaywallIdentifier = "main_paywall"
    var products: [ApphudProduct]?
    var paywall: ApphudPaywall?
    var dismissCompletion: (() -> Void)?

    @IBOutlet weak var paywallCollectionView: UICollectionView!

    override func viewDidLoad() {
        super.viewDidLoad()

        // First option
        // Returns nil if StoreKit products are not yet fetched from the App Store.
        Apphud.paywalls.map { (paywalls) in
            handlePaywallsReady(paywalls: paywalls)
        }

        // Second option
        // To get notified when paywalls are ready to use, use
        // paywallsDidLoadCallback – when it’s called,
        // paywalls are populated with their SKProducts.
        Apphud.paywallsDidLoadCallback { [weak self] (paywalls) in
            self?.handlePaywallsReady(paywalls: paywalls)
        }
    }

    private func handlePaywallsReady(paywalls: [ApphudPaywall]) {
        // retrieve current paywall with identifier
        self.paywall = paywalls.first(where: { $0.identifier == self.currentPaywallIdentifier })

        // retrieve the products [ApphudProduct] from current paywall
        self.products = self.paywall?.products

        // send Apphud log, that your paywall shown
        self.paywall.map { Apphud.paywallShown($0) }

        // setup your UI
        self.setupViewConfiguration()
    }

    override func viewWillDisappear(_ animated: Bool) {
        super.viewWillDisappear(animated)

        // send Apphud log, that your paywall closed
        self.paywall.map { Apphud.paywallClosed($0) }
        dismissCompletion?()
    }

    func setupViewConfiguration() {
        self.paywallCollectionView.reloadData()
    }
    @IBAction func closeView(_ sender: Any) {
        self.dismiss(animated: true, completion: nil)
    }
}

// MARK: - UICollectionViewDataSource, UICollectionViewDelegate, UICollectionViewDelegateFlowLayout
extension PaywallViewController: UICollectionViewDelegate, UICollectionViewDataSource, UICollectionViewDelegateFlowLayout {

    func collectionView(_ collectionView: UICollectionView, numberOfItemsInSection section: Int) -> Int {
        return products?.count ?? 0
    }

    func collectionView(_ collectionView: UICollectionView, cellForItemAt indexPath: IndexPath) -> UICollectionViewCell {
        let cell = collectionView.dequeueReusableCell(withReuseIdentifier: "PaywallCollectionViewCellid", for: indexPath) as! PaywallCollectionViewCell

        let product = products?[indexPath.item]
        cell.purchaseTypeLabel.text = product?.skProduct?.getProductDuration()
        cell.purchasePriceLabel.text = product?.skProduct?.getProductPrice()
        cell.purchaseDescriptionLabel.text = product?.skProduct?.localizedTitle

        return cell
    }

    func collectionView(_ collectionView: UICollectionView, didSelectItemAt indexPath: IndexPath) {
        if let product = products?[indexPath.item] {
            self.showLoader()
            Apphud.purchase(product) { (result) in
                self.hideLoader()
                if result.error == nil {
                    self.dismiss(animated: true, completion: nil)
                }
            }
        }
    }

    func collectionView(_ collectionView: UICollectionView, layout collectionViewLayout: UICollectionViewLayout, sizeForItemAt indexPath: IndexPath) -> CGSize {
        return CGSize(width: UIScreen.main.bounds.size.width, height: 150)
    }
}
