//
//  ApphudScreen.swift
//  Apphud, Inc
//
//  Created by ren6 on 26/08/2019.
//  Copyright © 2019 Apphud Inc. All rights reserved.
//

import UIKit

struct ApphudScreen {

    var status_bar_color: String?
    var name: String?

    init(dictionary: [String: Any]) {
        status_bar_color = dictionary["status_bar_color"] as? String
        name = dictionary["name"] as? String
    }
}
