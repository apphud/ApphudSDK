//
//  PaywallViewController.swift
//  ApphudSDKDemo
//
//  Created by Valery on 15.06.2021.
//  Copyright © 2021 softeam. All rights reserved.
//

import UIKit
import ApphudSDK
import StoreKit
import SwiftUI

enum PaywallID: String {
    case main // should be equal to identifier in your Apphud > Paywalls
}

class PaywallViewController: UIViewController {

    var paywallID: PaywallID!
    var dismissCompletion: (() -> Void)?
    var purchaseCallback: ((Bool) -> Void)? // callback style

    private var products = [ApphudProduct]()
    private var paywall: ApphudPaywall?

    @IBOutlet private var optionsStackView: UIStackView!
    private var selectedProduct: ApphudProduct?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavBar()
        Task {
            await loadPaywalls()
        }
    }

    // MARK: - ViewModel Methods

    private func loadPaywalls() async {
        let paywalls = await Apphud.paywalls()
        self.handlePaywallsReady(paywalls: paywalls)
    }

    private func handlePaywallsReady(paywalls: [ApphudPaywall]) {
        // retrieve current paywall with identifier
        self.paywall = paywalls.first(where: { $0.identifier == paywallID.rawValue })

        if paywall == nil {
            print("Couldn't find Paywall with Identifier: \(paywallID.rawValue)")
        }

        // retrieve the products [ApphudProduct] from current paywall
        self.products = self.paywall?.products ?? []

        // send Apphud log, that your paywall shown
        self.paywall.map { Apphud.paywallShown($0) }

        // setup your UI
        self.updateUI()
    }

    // MARK: - UI

    func updateUI() {
        if optionsStackView.arrangedSubviews.count == 0 {
            products.forEach { product in
                let optionView = PaywallOptionView.viewWith(product: product)
                optionsStackView.addArrangedSubview(optionView)
                optionView.addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(optionSelected)))
            }
        }

        optionsStackView.arrangedSubviews.forEach { v in
            if let optionView = v as? PaywallOptionView {
                optionView.isSelected = selectedProduct == optionView.product
            }
        }
    }

    @objc func optionSelected(gesture: UITapGestureRecognizer) {
        if let view = gesture.view as? PaywallOptionView {
            selectedProduct = view.product
            updateUI()
        }
    }

    private func setupNavBar() {
        navigationItem.leftBarButtonItem = UIBarButtonItem(barButtonSystemItem: .close, target: self, action: #selector(closeAction))
        navigationItem.rightBarButtonItem = UIBarButtonItem(title: "Restore", style: .done, target: self, action: #selector(restoreAction))
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)

        // send Apphud log, that your paywall closed
        self.paywall.map { Apphud.paywallClosed($0) }
        dismissCompletion?()
    }

    // MARK: - Actions

    func purchaseProduct(_ product: ApphudProduct) async {
        self.showLoader()

        let result = await Apphud.purchase(product)

        self.purchaseCallback?(result.error == nil)
        self.hideLoader()

        if result.error == nil {
            self.closeAction()
        }
    }

    @available(iOS 15.0, *)
    func purchaseProductStruct(_ product: ApphudProduct) async {
        if let productModel = await product.product() {
            self.showLoader()

            let result = await Apphud.purchase(productModel)

            self.purchaseCallback?(result.success)
            self.hideLoader()

            if result.error == nil {
                self.closeAction()
            }
        }
    }

    @objc private func restoreAction() {
        Task {
            showLoader()
            await Apphud.restorePurchases()
            hideLoader()
            if AppVariables.isPremium {
                closeAction()
            }
        }
    }

    @objc private func closeAction() {
        dismiss(animated: true, completion: nil)
    }

    @IBAction private func buttonAction() {
        guard let product = selectedProduct else {return}

        let sheet = UIAlertController(title: "Select purchase method", message: nil, preferredStyle: .actionSheet)
        sheet.addAction(UIAlertAction(title: "Purchase SKProduct", style: .default, handler: { _ in
            Task {
                await self.purchaseProduct(product)
            }
        }))
        sheet.addAction(UIAlertAction(title: "Purchase Product struct", style: .default, handler: { _ in
            Task {
                if #available(iOS 15.0, *) {
                    Apphud.migratePurchasesIfNeeded { _, _, _ in }
                    await self.purchaseProductStruct(product)
                } else {
                    await self.purchaseProduct(product)
                }
            }
        }))
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))
        present(sheet, animated: true)
    }
}
