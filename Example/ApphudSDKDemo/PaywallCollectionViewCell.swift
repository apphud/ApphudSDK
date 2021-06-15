//
//  PaywallCollectionViewCell.swift
//  ApphudSDKDemo
//
//  Created by Валерий Левшин on 15.06.2021.
//  Copyright © 2021 softeam. All rights reserved.
//

import UIKit

class PaywallCollectionViewCell: UICollectionViewCell {
    
    @IBOutlet weak var purchaseTypeLabel: UILabel!
    @IBOutlet weak var purchasePriceLabel: UILabel!
    @IBOutlet weak var purchaseDescriptionLabel: UILabel!
    
    var animatingHighlight = false
    
    override var isHighlighted: Bool {
        didSet {
            if isHighlighted {
                animatingHighlight = true
                animate(highlight: true) {
                    self.animatingHighlight = false
                    if !self.isHighlighted {
                        self.animate(highlight: false)
                    }
                }
            } else if !animatingHighlight {
                animate(highlight: false)
            }
        }
    }
        
    func animate(highlight: Bool, completion: (()->())? = nil) {
        let duration = 0.1
        let scale: CGFloat = 0.92
        
        UIView.animate(withDuration: duration,
                       delay: 0,
                       options: [.curveEaseInOut],
                       animations: {
                        self.transform = highlight ? CGAffineTransform(scaleX: scale, y: scale) : .identity
        }) { finished in
            completion?()
        }
    }
    
}
