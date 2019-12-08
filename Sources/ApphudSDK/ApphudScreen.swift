//
//  ApphudScreen.swift
//  apphud
//
//  Created by Renat on 26/08/2019.
//  Copyright © 2019 softeam. All rights reserved.
//

import UIKit

struct ApphudScreen {
    
    var identifier: String
    var name: String
    var terms_url: String?
    var privacy_url: String?
    var status_bar_color: String?
    var products_offers_map : [[String : Any]]?
    
    init(dictionary: [String : Any]) {
        name = dictionary["name"] as? String ?? ""
        identifier = dictionary["identifier"] as? String ?? ""
        terms_url = dictionary["terms_url"] as? String ?? ""
        privacy_url = dictionary["privacy_url"] as? String ?? ""        
        status_bar_color = dictionary["status_bar_color"] as? String ?? ""
        products_offers_map = dictionary["products"] as? [[String : Any]]
    }
}
