//
//  ApphudRule.swift
//  apphud
//
//  Created by Renat on 30/08/2019.
//  Copyright © 2019 softeam. All rights reserved.
//

import UIKit

struct ApphudRule {    
    var id: String
    var screen_id: String
    init(dictionary: [String : Any]) {
        id = dictionary["id"] as? String ?? ""
        screen_id = dictionary["screen_id"] as? String ?? ""
    }
}
