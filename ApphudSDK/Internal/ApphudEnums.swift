//
//  ApphudEnums.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 28.09.2023.
//

import Foundation

internal enum ApphudIAPCodingKeys: String, CodingKey {
    case id, expiresAt, productId, cancelledAt, startedAt, inRetryBilling, autorenewEnabled, introductoryActivated, environment, local, groupId, status, kind
}

internal enum ApphudIAPKind: String {
    case autorenewable
    case nonrenewable
}

internal enum ApphudEnvironment: String {
    case sandbox
    case production
}
