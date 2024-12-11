
import Foundation
import AppMetricaCoreExtension

protocol ApphudStartupObservingDelegate: AnyObject {
    func startupUpdated()
}

final class ApphudStartupController : NSObject, ExtendedStartupObserving, ReporterStorageControlling {
    
    weak var delegate: ApphudStartupObservingDelegate?
    private var startupStorageProvider: StartupStorageProviding?
    private var startupStorage: KeyValueStoring?
    private let responseParser: ApphudStartupResponseParsing
    
    init(responseParser: ApphudStartupResponseParsing = ApphudStartupResponseParser()) {
        self.responseParser = responseParser
    }
    
    private(set) var startupConfiguration: ApphudStartupConfiguration?
    
    //MARK: - ExtendedStartupObserving -
    func startupParameters() -> [AnyHashable : Any] {
        return ["request" : ApphudStartupRequestParameters().parameters]
    }
    
    func startupUpdated(withParameters parameters: [AnyHashable : Any]) {
        guard let startupStorage = self.startupStorage else { return }
        self.startupConfiguration = self.responseParser.startupConfiguration(storage: startupStorage,
                                                                             response: parameters)
        self.startupStorageProvider?.saveStorage(startupStorage)
        self.delegate?.startupUpdated()
    }
    
    func setupStartupProvider(_ startupStorageProvider: any StartupStorageProviding,
                              cachingStorageProvider: any CachingStorageProviding) {
        self.startupStorageProvider = startupStorageProvider
        let startupStorage = startupStorageProvider.startupStorage(forKeys: ApphudStartupConfiguration.allKeys)
        self.startupStorage = startupStorage
        self.startupConfiguration = ApphudStartupConfiguration(storage: startupStorage)
        self.delegate?.startupUpdated()
    }
    
    //MARK: - ReporterStorageControlling -
    func setup(withReporterStorage stateStorageProvider: any KeyValueStorageProviding,
               main: Bool,
               forAPIKey apiKey: String) {}
}
