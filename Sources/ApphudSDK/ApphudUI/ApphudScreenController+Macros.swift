//
//  ApphudScreenController+JS.swift
//  apphud
//
//  Created by Renat on 01.07.2020.
//  Copyright © 2020 softeam. All rights reserved.
//

import Foundation
import StoreKit

extension ApphudScreenController {
    func replaceStringFor(product: SKProduct, offerID: String? = nil) -> String {
        if offerID != nil {
            if #available(iOS 12.2, *) {
                if let discount = product.discounts.first(where: {$0.identifier == offerID!}) {
                    return product.apphudLocalizedDiscountPrice(discount: discount)
                } else {
                    apphudLog("Couldn't find promo offer with id: \(offerID!) in product: \(product.productIdentifier), available promo offer ids: \(product.apphudPromoIdentifiers())", forceDisplay: true)
                    return ""
                }
            } else {
                apphudLog("Promo offers are not available under iOS 12.2, offerID: \(offerID!) in product: \(product.productIdentifier)", forceDisplay: true)
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
            var tempString: NSString?
            scanner.scanUpTo("{{\"", into: &tempString)
            if tempString != nil {
                scanner.scanUpTo("}}", into: &tempString)
                if scanner.isAtEnd {
                    shouldScan = false
                } else {
                    macroses.append("\(tempString as String? ?? "")}}")
                }
            } else {
                shouldScan = false
            }
        }

        var productsOffersMap = [[String: String]]()

        for macros in macroses {
            let scanner = Scanner(string: macros)
            var tempString: NSString?

            var dict = [String: String]()
            dict["macros"] = macros
            if scanner.scanUpTo("\"", into: &tempString) && !scanner.isAtEnd {
                scanner.scanLocation += 1
                scanner.scanUpTo("\"", into: &tempString)

                if let product_id = tempString as String? {
                    dict["product_id"] = product_id
                }

                if scanner.scanUpTo("price: \"", into: &tempString) && !scanner.isAtEnd {
                    scanner.scanLocation += 8
                    scanner.scanUpTo("\"", into: &tempString)
                    if let offer_id = (tempString as String?) {
                        dict["offer_id"] = offer_id
                    }
                }
            }
            productsOffersMap.append(dict)
        }

        self.macrosesMap = productsOffersMap

        // replace macroses
        self.replaceMacroses()
    }

    @objc func replaceMacroses() {

        if ApphudStoreKitWrapper.shared.products.count == 0 {
            addObserverIfNeeded()
            return
        }

        var html: NSString = self.originalHTML! as NSString

        for macrosDict in self.macrosesMap {

            guard let macros = macrosDict["macros"] else { continue }

            var replace_string = ""

            if let product_id = macrosDict["product_id"], let product = ApphudStoreKitWrapper.shared.products.first(where: {$0.productIdentifier == product_id}) {
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
