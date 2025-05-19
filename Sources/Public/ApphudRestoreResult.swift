//
//  ApphudRestoreResult.swift
//  Pods
//
//  Created by Renat Kurbanov on 19.05.2025.
//

public struct ApphudRestoreResult {
    var subscriptions: [ApphudSubscription]?
    var nonRenewingPurchases: [ApphudNonRenewingPurchase]?
    var error: Error?
}
