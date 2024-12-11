
import Foundation
import AppMetricaCoreExtension
import ApphudSDK

@objc(AMAApphudManager)
final public class ApphudManager: NSObject, ModuleActivationDelegate, ApphudStartupObservingDelegate {
    
    @objc public static let shared = ApphudManager()
    
    private var apphudInitializer: ApphudInitializing
    private let startupController: ApphudStartupController
    private var shouldWaitForStartup: Bool = false
    
    init(startupController: ApphudStartupController = ApphudStartupController(),
         apphudInitializer: ApphudInitializing = ApphudInitializer()) {
        self.apphudInitializer = apphudInitializer
        self.startupController = startupController
        super.init()
        startupController.delegate = self
    }
    
    func startIfNeeded() {
        guard let apiKey = self.apphudApiKey else {
            self.shouldWaitForStartup = true
            return
        }
        
        self.startApphud(apiKey: apiKey)
    }
    
    func startupUpdated() {
        guard self.shouldWaitForStartup, let apiKey = self.apphudApiKey else { return }
        self.startApphud(apiKey: apiKey)
        self.shouldWaitForStartup = false
    }
    
    @objc public var serviceConfiguration: ServiceConfiguration {
        return ServiceConfiguration(startupObserver: self.startupController,
                                    reporterStorageController: self.startupController)
    }
    
    @objc(setApphudInitializerImpl:)
    public func setApphudInitializerImpl(apphudInitializer: ApphudInitializing) {
        self.apphudInitializer = apphudInitializer
    }
    
    //MARK: - ModuleActivationDelegate -
    public static func willActivate(with configuration: ModuleActivationConfiguration) {}
    
    public static func didActivate(with configuration: ModuleActivationConfiguration) {
        ApphudManager.shared.startIfNeeded()
    }
    
    private var apphudApiKey: String? {
        guard let apiKey = self.startupController.startupConfiguration?.apphudAPIKey,
              !apiKey.isEmpty,
                let enabled = self.startupController.startupConfiguration?.apphudEnabled?.boolValue,
              enabled else { return nil }
        return apiKey
    }
    
    private func startApphud(apiKey: String) {
        self.apphudInitializer.activateApphud(apiKey: apiKey,
                                              userID: AppMetrica.uuid, 
                                              deviceID: AppMetrica.deviceID,
                                              observerMode: true)
    }
}
