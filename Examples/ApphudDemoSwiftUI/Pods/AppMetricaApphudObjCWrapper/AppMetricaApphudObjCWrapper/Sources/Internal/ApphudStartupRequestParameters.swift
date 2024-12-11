
import Foundation

final class ApphudStartupRequestParameters {

    var parameters: [AnyHashable: Any] {
        let features = featureParameters.joined(separator: ",")
        var params: [String: String] = ["features": features]
        params.merge(blockParameters) { (_, new) in new }
        return params
    }

    private var featureParameters: [String] {
        return ["ah"]
    }

    private var blockParameters: [String: String] {
        return ["ah": "1"]
    }
}
