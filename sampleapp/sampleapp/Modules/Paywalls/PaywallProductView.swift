//
//  PaywallProductView.swift
//  sampleapp
//
//  Created by Apphud on 13.02.2024.
//  Copyright © 2024 Apphud. All rights reserved.
//

import UIKit
import ApphudSDK

class PaywallProductView: UIView {
    
    private(set) var product: ApphudProduct!
    
    static func viewWith(product: ApphudProduct) -> PaywallProductView {
        let view = PaywallProductView()
        view.product = product
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 60).isActive = true
        view.setup(product)
        return view
    }
    
    var isSelected: Bool = false {
        didSet {
            
            layer.borderColor = isSelected ? UIColor.systemBlue.cgColor : UIColor.label.withAlphaComponent(0.1).cgColor
            layer.borderWidth = 2
            layer.cornerRadius = 30
        }
    }
    
    private lazy var titleLabel: UILabel = {
        let label = UILabel()
        label.font = UIFont.systemFont(ofSize: 17, weight: .regular)
        addSubview(label)
        label.numberOfLines = 1
        label.minimumScaleFactor = 0.5
        label.translatesAutoresizingMaskIntoConstraints = false
        label.leadingAnchor.constraint(equalTo: self.leadingAnchor, constant: 20).isActive = true
        label.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        return label
    }()
    
    private func setup(_ product: ApphudProduct) {
        titleLabel.text = product.skProduct?.pricingDescription() ?? "Loading..."
    }
}
