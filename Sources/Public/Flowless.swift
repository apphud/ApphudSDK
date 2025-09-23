//
//  Flowless.swift
//  ApphudSDK
//
//  Created by Renat Kurbanov on 17.09.2025.
//

import Foundation

final public class Flowless {
    
    /**
     Initializes Flowless SDK. Call this during the app's launch.

     - parameter apiKey: Required. Your API key.
     - parameter userID: Optional. Provide your own unique user identifier, or if `nil`, a UUID will be generated.
     - parameter observerMode: Optional. Sets SDK to Observer (Analytics) mode. Pass `true` if you handle product purchases with your own code, or `false` if you use the `Apphud.purchase(..)` method. The default value is `false`. This mode influences analytics and data collection behaviors.
     - parameter callback: Optional. Called when the user is successfully registered in Apphud [or retrieved from cache]. Use this to fetch raw placements or paywalls.
     */
    @MainActor
    public static func start(apiKey: String, callback: (() -> Void)? = nil) {
        FlowlessHttpClient.shared.apiKey = apiKey
    }

}
