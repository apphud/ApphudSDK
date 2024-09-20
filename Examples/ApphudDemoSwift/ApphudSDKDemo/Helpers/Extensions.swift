//
//  Extensions.swift
//  Apphud, Inc
//
//  Created by ren6 on 04/09/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import Foundation
import UIKit
import ApphudSDK

extension UIStackView {
    func removeAllArrangedSubviews() {
        arrangedSubviews.forEach {
            self.removeArrangedSubview($0)
            NSLayoutConstraint.deactivate($0.constraints)
            $0.removeFromSuperview()
        }
    }
}

@MainActor
struct LoaderDialog {
    static var alert = UIAlertController()
    static var progressView = UIProgressView()
    static var progressPoint: Float = 0 {
        didSet {
            if progressPoint == 1 {
                LoaderDialog.alert.dismiss(animated: true, completion: nil)
            }
        }
    }
}

extension UIViewController {
    func showLoader() {
        LoaderDialog.alert = UIAlertController(title: nil, message: "Connecting to Apple...", preferredStyle: .alert)

        let loadingIndicator = UIActivityIndicatorView(frame: CGRect(x: 10, y: 5, width: 50, height: 50))
        loadingIndicator.hidesWhenStopped = true
        loadingIndicator.style = .medium
        loadingIndicator.startAnimating()

        LoaderDialog.alert.view.addSubview(loadingIndicator)
        present(LoaderDialog.alert, animated: true, completion: nil)
    }

    func hideLoader() {
        LoaderDialog.alert.dismiss(animated: true, completion: nil)
    }
}

extension ApphudSubscriptionStatus {
    /**
     This function can only be used in Swift
     */
    func toStringDuplicate() -> String {

        switch self {
        case .trial:
            return "trial"
        case .intro:
            return "intro"
        case .promo:
            return "promo"
        case .grace:
            return "grace"
        case .regular:
            return "regular"
        case .refunded:
            return "refunded"
        case .expired:
            return "expired"
        }
    }
}
