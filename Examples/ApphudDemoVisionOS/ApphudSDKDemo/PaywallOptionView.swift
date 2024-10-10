//
//  PaywallOptionView.swift
//  ApphudSDKDemo
//
//  Created by Renat Kurbanov on 13.02.2023.
//  Copyright © 2023 Apphud. All rights reserved.
//

import Foundation
import ApphudSDK
import UIKit

class PaywallOptionView: UIView {

    private(set) var product: ApphudProduct!

    static func viewWith(product: ApphudProduct) -> PaywallOptionView {
        let view = PaywallOptionView()
        view.product = product
        view.translatesAutoresizingMaskIntoConstraints = false
        view.heightAnchor.constraint(equalToConstant: 70).isActive = true
        Task { await view.setup(product) }
        return view
    }

    var isSelected: Bool = false {
        didSet {
            selectionImage.image = UIImage(systemName: isSelected ? "checkmark.circle.fill" : "circle")
            layer.borderColor = isSelected ? UIColor.systemBlue.cgColor : UIColor.label.withAlphaComponent(0.1).cgColor
            layer.borderWidth = 2
            layer.cornerRadius = 35
            selectionImage.tintColor = isSelected ? UIColor.systemBlue : UIColor.label.withAlphaComponent(0.1)
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
        label.trailingAnchor.constraint(equalTo: selectionImage.leadingAnchor, constant: 10).isActive = true
        label.centerYAnchor.constraint(equalTo: self.centerYAnchor).isActive = true
        return label
    }()

    private lazy var selectionImage: UIImageView = {
        let imgView = UIImageView(image: UIImage(systemName: "circle")?.withRenderingMode(.alwaysTemplate))
        addSubview(imgView)
        imgView.translatesAutoresizingMaskIntoConstraints = false
        imgView.trailingAnchor.constraint(equalTo: trailingAnchor, constant: -10).isActive = true
        imgView.centerYAnchor.constraint(equalTo: centerYAnchor).isActive = true
        imgView.widthAnchor.constraint(equalToConstant: 25).isActive = true
        imgView.heightAnchor.constraint(equalToConstant: 25).isActive = true
        return imgView
    }()

    private func setup(_ product: ApphudProduct) async {
        titleLabel.text = (try? await product.product()?.displayPrice) ?? "Loading..."
    }
}
