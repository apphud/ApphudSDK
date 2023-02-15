//
//  AppVariables.swift
//  ApphudSDKDemo
//
//  Created by Renat Kurbanov on 13.02.2023.
//  Copyright © 2023 softeam. All rights reserved.
//

import Foundation
import ApphudSDK

class AppVariables {

    static let lifetimeProductID = "com.apphud.gold"

    static var isPremium: Bool {
        Apphud.hasActiveSubscription() ||
        Apphud.isNonRenewingPurchaseActive(productIdentifier: lifetimeProductID)
    }
}
