//
//  ApphudError.swift
//  Apphud, Inc
//
//  Created by ren6 on 31.05.2020.
//  Copyright © 2020 Apphud Inc. All rights reserved.
//

import UIKit

public class ApphudError: NSError {

    private let codeDomain = "com.apphud.error"

    init(message: String) {
        super.init(domain: codeDomain, code: 0, userInfo: [NSLocalizedDescriptionKey: message])
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
