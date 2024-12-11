
import Foundation
import AppMetricaStorageUtils

protocol ApphudStartupResponseParsing {
    func startupConfiguration(storage: KeyValueStoring, response: [AnyHashable: Any]) -> ApphudStartupConfiguration
}

final class ApphudStartupResponseParser: ApphudStartupResponseParsing {
    
    func startupConfiguration(storage: KeyValueStoring, response: [AnyHashable: Any]) -> ApphudStartupConfiguration {
        let startupConfiguration = ApphudStartupConfiguration(storage: storage)
        if let features = (response["features"] as? [String: Any])?["list"] as? [String: Any],
           let apphudFeature = features["apphud"] as? [String: Any],
           let enabled = apphudFeature["enabled"] as? NSNumber {
            startupConfiguration.apphudEnabled = enabled
        }
        
        if let apphudData = response["apphud"] as? [String: Any],
           let apiKey = apphudData["apikey"] as? String {
            startupConfiguration.apphudAPIKey = apiKey
        }
        
        return startupConfiguration
    }
}
