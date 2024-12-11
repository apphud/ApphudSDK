
import Foundation
import ApphudSDK
import AppMetricaCore

@objc(AMAApphudInitializing)
public protocol ApphudInitializing {
    func activateApphud(apiKey: String, userID: String?, deviceID: String?, observerMode: Bool)
}

final class ApphudInitializer: ApphudInitializing {
    func activateApphud(apiKey: String, userID: String?, deviceID: String?, observerMode: Bool) {
        Task { @MainActor in
            Apphud.startManually(apiKey: apiKey, userID: userID, deviceID: deviceID, observerMode: observerMode)
        }
    }
}
