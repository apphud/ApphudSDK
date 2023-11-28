//
//  ApphudPlacement.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 27.11.2023.
//

import Foundation

public struct ApphudPlacement: Codable {
    
    public var identifier: String
    public var name: String
    public var paywall: ApphudPaywall?

    internal var id: String
}
