//
//  AppVariables.swift
//  ApphudDemoSwiftUI
//
//  Created by Renat Kurbanov on 15.02.2023.
//

import Foundation
import ApphudSDK

class AppVariables {

    static let lifetimeProductID = "com.apphud.gold"

    @MainActor
    static var isPremium: Bool {
        Apphud.hasActiveSubscription() ||
        Apphud.isNonRenewingPurchaseActive(productIdentifier: lifetimeProductID)
    }
}
