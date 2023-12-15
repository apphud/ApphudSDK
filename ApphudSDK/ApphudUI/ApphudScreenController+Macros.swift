//
//  ApphudScreenController+JS.swift
//  apphud
//
//  Created by Renat on 01.07.2020.
//  Copyright © 2020 Apphud Inc. All rights reserved.
//

#if canImport(UIKit)
import UIKit
#endif
import Foundation
import StoreKit

#if os(iOS)
extension ApphudScreenController {
    func replaceStringFor(product: SKProduct, offerID: String? = nil) -> String {
        if offerID != nil {
                if let discount = product.discounts.first(where: {$0.identifier == offerID!}) {
                    return product.apphudLocalizedDiscountPrice(discount: discount)
                } else {
                    apphudLog("Couldn't find promo offer with id: \(offerID!) in product: \(product.productIdentifier), available promo offer ids: \(product.apphudPromoIdentifiers())", forceDisplay: true)
                    return ""
                }
        } else {
            return product.apphudLocalizedPrice()
        }
    }

    func extractMacrosesUsingRegexp() {

        guard self.originalHTML != nil else {return}
        let scanner = Scanner(string: self.originalHTML!)

        var shouldScan = true

        var macroses = [String]()

        while shouldScan {
            if let _ = scanner.scanUpToString("{{\"") {
                let macro = scanner.scanUpToString("}}")
                if scanner.isAtEnd {
                    shouldScan = false
                } else {
                    macroses.append("\(macro as String? ?? "")}}")
                }
            } else {
                shouldScan = false
            }
        }

        var productsOffersMap = [[String: String]]()

        for macros in macroses {

            let filtered = macros.replacingOccurrences(of: "{{", with: "")
                .replacingOccurrences(of: "}}", with: "")
                .replacingOccurrences(of: "\"", with: "")
                .replacingOccurrences(of: " | price:", with: "|||")
                .replacingOccurrences(of: " | price", with: "|||")
                .replacingOccurrences(of: " ", with: "")

            let components = filtered.components(separatedBy: "|||")

            var dict = [String: String]()
            dict["macros"] = macros
            (components.first).map { dict["product_id"] = $0 }
            if components.count == 2, let offerId = components.last, offerId.count > 0 {
                dict["offer_id"] = offerId
            }
            productsOffersMap.append(dict)
        }

        self.macrosesMap = productsOffersMap

        Task {
            // replace macroses
            await self.replaceMacroses()
        }
    }

    @objc func replaceMacroses() async {

        let mentionedProducts = macrosesMap.compactMap { $0["product_id"] }

        let products = await ApphudStoreKitWrapper.shared.fetchProducts(mentionedProducts)

        var html: NSString = self.originalHTML! as NSString

        for macrosDict in self.macrosesMap {

            guard let macros = macrosDict["macros"] else { continue }

            var replace_string = ""

            if let product_id = macrosDict["product_id"], let product = products?.first(where: {$0.productIdentifier == product_id}) {
                if let offer_id = macrosDict["offer_id"] {
                    replace_string = replaceStringFor(product: product, offerID: offer_id)
                } else {
                    replace_string = replaceStringFor(product: product)
                }
            }

            html = html.replacingOccurrences(of: macros, with: replace_string) as NSString
        }

        self.editAndReloadPage(html: html as String)
    }
}
#endif
