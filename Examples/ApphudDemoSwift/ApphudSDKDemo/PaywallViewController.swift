//
//  PaywallViewController.swift
//  ApphudSDKDemo
//
//  Created by Valery on 15.06.2021.
//  Copyright © 2021 Apphud. All rights reserved.
//

import UIKit
import ApphudSDK
import StoreKit
import SwiftUI

enum PlacementID: String {
    case main // should be equal to identifier in your Apphud > Placements
    case onboarding
}

class PaywallViewController: UIViewController {

    var dismissCompletion: (() -> Void)?
    var purchaseCallback: ((Bool) -> Void)? // callback style

    private var products = [ApphudProduct]()
    private var paywall: ApphudPaywall?

    @IBOutlet private var optionsStackView: UIStackView!
    private var selectedProduct: ApphudProduct?

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNavBar()
        Task { @MainActor in
            await loadPaywalls()
//            await loadProducts()
        }
    }

    // MARK: - ViewModel Methods

    private func loadProducts() async {
        do {
            if #available(iOS 15.0, *) {
                let products = try await Apphud.fetchProducts()
                print("products successfully fetched: \(products.map { $0.id })")
            }
        } catch {
            print("products fetch error = \(error)")
        }
    }

    private func loadPaywalls() async {
        let placements = await Apphud.placements()
        let placement = placements.first(where: { $0.identifier == PlacementID.onboarding.rawValue }) ?? placements.first
        if let paywall = placement?.paywall {
            self.handlePaywallReady(paywall: paywall)
        }
    }

    private func handlePaywallReady(paywall: ApphudPaywall) {
        self.paywall = paywall
        // retrieve the products [ApphudProduct] from current paywall
        self.products = paywall.products

        // send Apphud log, that your paywall shown
        Apphud.paywallShown(paywall)

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
        if let productModel = try? await product.product() {
            self.showLoader()

//            Apphud.setCustomPurchaseValue(1.23, productId: product.productId)

            let result = await Apphud.purchase(productModel)

            self.purchaseCallback?(result.success)
            self.hideLoader()

            if result.error == nil {
                self.closeAction()
            }
        }
    }

    @objc private func restoreAction() {
        Task { @MainActor in
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
            Task { @MainActor in
                await self.purchaseProduct(product)
            }
        }))
        sheet.addAction(UIAlertAction(title: "Purchase Product struct", style: .default, handler: { _ in
            Task { @MainActor in
                if #available(iOS 15.0, *) {
                    await self.purchaseProductStruct(product)
                } else {
                    await self.purchaseProduct(product)
                }
            }
        }))
        sheet.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        if let popoverController = sheet.popoverPresentationController {
            popoverController.sourceView = self.view // The view containing the anchor rectangle for the popover.
            popoverController.sourceRect = CGRect(x: self.view.bounds.midX, y: self.view.bounds.midY, width: 0, height: 0) // The rectangle in the specified view in which to anchor the popover.
            popoverController.permittedArrowDirections = [] // Optional: No arrow or specify direction
        }

        present(sheet, animated: true)
    }
}
