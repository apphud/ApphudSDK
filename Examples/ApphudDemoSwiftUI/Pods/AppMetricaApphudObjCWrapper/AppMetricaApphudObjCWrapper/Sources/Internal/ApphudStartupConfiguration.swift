
import Foundation
import AppMetricaStorageUtils

final class ApphudStartupConfiguration {
    
    static let apphudStorageKey = "apphud.api.key"
    static let apphudEnabledKey = "apphud.enabled"
    
    private(set) var storage: KeyValueStoring
    
    init(storage: KeyValueStoring) {
        self.storage = storage
    }
    
    var apphudAPIKey: String? {
        get {
            return try? self.storage.string(forKey: Self.apphudStorageKey)
        }
        set {
            try? self.storage.save(newValue, forKey: Self.apphudStorageKey)
        }
    }
    
    var apphudEnabled: NSNumber? {
        get {
            return try? self.storage.boolNumber(forKey: Self.apphudEnabledKey)
        }
        set {
            try? self.storage.saveBoolNumber(newValue, forKey: Self.apphudEnabledKey)
        }
    }
    
    static var allKeys: [String] {
        return [apphudStorageKey,
                apphudEnabledKey]
    }
}
