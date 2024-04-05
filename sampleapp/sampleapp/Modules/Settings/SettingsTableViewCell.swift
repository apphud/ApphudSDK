//
//  SettingsTableViewCell.swift
//  sampleapp
//
//  Created by Apphud on 13.02.2024.
//  Copyright © 2024 Apphud. All rights reserved.
//

import UIKit

class SettingsTableViewCell: UITableViewCell {
    
    @IBOutlet weak var leftLabel: UILabel!
    @IBOutlet weak var rightLabel: UILabel!
    
    override func awakeFromNib() {
        super.awakeFromNib()
        // Initialization code
    }
    
    override func setSelected(_ selected: Bool, animated: Bool) {
        super.setSelected(selected, animated: animated)
        // Configure the view for the selected state
    }
    
    func fillCell(type:MenuCellType) {
        var title = ""
        var desc = ""
        
        switch type {
        case let .appversion(tx1,tx2):
            title = tx1
            desc = tx2
        case let .sdkversion(tx1,tx2):
            title = tx1
            desc = tx2
        case let .restore(tx1,tx2):
            title = tx1
            desc = tx2
        case let .status(tx1,tx2):
            title = tx1
            desc = tx2
        }
        
        leftLabel.text = title
        rightLabel.text = desc
    }
}
