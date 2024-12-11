
#import "AMACore.h"
#import "AMAAppMetrica+Internal.h"
#import "AMAAppMetricaConfigurationManager.h"
#import "AppMetricaConfigForAnonymousActivationProvider.h"
#import "AMALocationManager.h"
#import "AMAMetricaConfiguration.h"
#import "AMADataSendingRestrictionController.h"
#import "AMAAppMetricaConfiguration+Internal.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAReporterConfiguration+Internal.h"
#import "AMAMetricaInMemoryConfiguration.h"
#import "AMAMetricaParametersScanner.h"
#import "AMAErrorLogger.h"
#import "AMADispatchStrategiesContainer.h"
#import "AMADatabaseQueueProvider.h"
#import "AppMetricaDefaultAnonymousConfigProvider.h"

@interface AMAAppMetricaConfigurationManager ()

@property (nonatomic, strong) id<AMAAsyncExecuting, AMASyncExecuting> executor;
@property (nonatomic, strong) AppMetricaConfigForAnonymousActivationProvider *anonymousConfigProvider;
@property (nonatomic, strong) AMAMetricaConfiguration *metricaConfiguration;
@property (nonatomic, strong) AMALocationManager *locationManager;
@property (nonatomic, strong) AMADataSendingRestrictionController *restrictionController;
@property (nonatomic, strong) AMADispatchStrategiesContainer *strategiesContainer;

@end

@implementation AMAAppMetricaConfigurationManager

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting,AMASyncExecuting>)executor
             strategiesContainer:(AMADispatchStrategiesContainer *)strategiesContainer
         firstActivationDetector:(AMAFirstActivationDetector *)firstActivationDetector
{
    AMAMetricaConfiguration *metricaConfiguration = [AMAMetricaConfiguration sharedInstance];
    AppMetricaConfigForAnonymousActivationProvider *anonymousConfigProvider =
        [[AppMetricaConfigForAnonymousActivationProvider alloc] initWithStorage:metricaConfiguration.persistent
                                                                defaultProvider:[[AppMetricaDefaultAnonymousConfigProvider alloc] init]
                                                        firstActivationDetector:firstActivationDetector];
    return [self initWithExecutor:executor
              strategiesContainer:strategiesContainer
             metricaConfiguration:metricaConfiguration
                  locationManager:[AMALocationManager sharedManager]
            restrictionController:[AMADataSendingRestrictionController sharedInstance]
          anonymousConfigProvider:anonymousConfigProvider];
}

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting,AMASyncExecuting>)executor
             strategiesContainer:(AMADispatchStrategiesContainer *)strategiesContainer
            metricaConfiguration:(AMAMetricaConfiguration *)metricaConfiguration
                 locationManager:(AMALocationManager *)locationManager
           restrictionController:(AMADataSendingRestrictionController *)restrictionController
         anonymousConfigProvider:(AppMetricaConfigForAnonymousActivationProvider *)anonymousConfigProvider
{
    self = [super init];
    if (self != nil) {
        _executor = executor;
        _strategiesContainer = strategiesContainer;
        _metricaConfiguration = metricaConfiguration;
        _locationManager = locationManager;
        _restrictionController = restrictionController;
        _anonymousConfigProvider = anonymousConfigProvider;
    }
    return self;
}

- (void)updateMainConfiguration:(AMAAppMetricaConfiguration *)configuration
{
    if (configuration == nil) {
        return;
    }
    [self importLogConfiguration:configuration];
    
    [self importLocationConfiguration:configuration];
    [self importDataSendingEnabledConfiguration:configuration];
    self.metricaConfiguration.persistent.userStartupHosts = configuration.customHosts;
    
    [self setPreloadInfo:configuration.preloadInfo];
    
    [self importReporterConfiguration:configuration];
    [self importCustomVersionConfiguration:configuration];
    
    self.metricaConfiguration.persistent.appMetricaClientConfiguration = configuration;
    
    self.metricaConfiguration.persistent.recentMainApiKey = configuration.APIKey;
    
    [self handleConfigurationUpdate];
}

- (void)updateReporterConfiguration:(AMAReporterConfiguration *)configuration
{
    AMADataSendingRestriction restriction = AMADataSendingRestrictionUndefined;
    if (configuration.dataSendingEnabledState != nil) {
        restriction = [configuration.dataSendingEnabledState boolValue]
            ? AMADataSendingRestrictionAllowed
            : AMADataSendingRestrictionForbidden;
    }
    [self.restrictionController setReporterRestriction:restriction
                                             forApiKey:configuration.APIKey];
    
    [self.metricaConfiguration setConfiguration:configuration];
    
    [self handleConfigurationUpdate];
}

- (AMAAppMetricaConfiguration *)anonymousConfiguration
{
    return [self.anonymousConfigProvider configuration];
}

#pragma mark - Handle configuration
- (void)importDataSendingEnabledConfiguration:(AMAAppMetricaConfiguration *)configuration
{
    AMADataSendingRestriction restriction = AMADataSendingRestrictionUndefined;
    if (configuration.dataSendingEnabledState != nil) {
        restriction = [configuration.dataSendingEnabledState boolValue]
            ? AMADataSendingRestrictionAllowed
            : AMADataSendingRestrictionForbidden;
    }

    [self.restrictionController setMainApiKey:configuration.APIKey];
    [self.restrictionController setMainApiKeyRestriction:restriction];
}

- (void)importLocationConfiguration:(AMAAppMetricaConfiguration *)configuration
{
    if (configuration.locationTrackingState != nil) {
        AMAAppMetrica.locationTrackingEnabled = configuration.locationTracking;
    }
    if (configuration.customLocation != nil) {
        AMAAppMetrica.customLocation = configuration.customLocation;
    }
    AMAAppMetrica.accurateLocationTrackingEnabled = configuration.accurateLocationTracking;
}

- (void)importReporterConfiguration:(AMAAppMetricaConfiguration *)configuration
{
    AMAMutableReporterConfiguration *appConfiguration =
        [self.metricaConfiguration.appConfiguration mutableCopy];
    appConfiguration.APIKey = configuration.APIKey;
    appConfiguration.sessionTimeout = configuration.sessionTimeout;
    appConfiguration.maxReportsCount = configuration.maxReportsCount;
    appConfiguration.maxReportsInDatabaseCount = configuration.maxReportsInDatabaseCount;
    appConfiguration.dispatchPeriod = configuration.dispatchPeriod;
    appConfiguration.logsEnabled = configuration.areLogsEnabled;
    appConfiguration.dataSendingEnabled = configuration.dataSendingEnabled;
    self.metricaConfiguration.appConfiguration = [appConfiguration copy];

    self.metricaConfiguration.inMemory.handleFirstActivationAsUpdate = configuration.handleFirstActivationAsUpdate;
    self.metricaConfiguration.inMemory.handleActivationAsSessionStart = configuration.handleActivationAsSessionStart;
    self.metricaConfiguration.inMemory.sessionsAutoTracking = configuration.sessionsAutoTracking;
}

- (void)importCustomVersionConfiguration:(AMAAppMetricaConfiguration *)configuration
{
    if (configuration.appVersion.length != 0) {
        self.metricaConfiguration.inMemory.appVersion = configuration.appVersion;
    }
    if (configuration.appBuildNumber.length != 0) {
        uint32_t uintBuildNumber = 0;
        BOOL isNewValueValid = [AMAMetricaParametersScanner scanAppBuildNumber:&uintBuildNumber
                                                                      inString:configuration.appBuildNumber];
        if (isNewValueValid) {
            self.metricaConfiguration.inMemory.appBuildNumber = uintBuildNumber;
            self.metricaConfiguration.inMemory.appBuildNumberString = configuration.appBuildNumber;
        } else {
            [AMAErrorLogger logInvalidCustomAppBuildNumberError];
        }
    }
}

- (void)importLogConfiguration:(AMAAppMetricaConfiguration *)configuration
{
    [AMAAppMetrica setLogs:configuration.areLogsEnabled];
    [self.executor execute:^{
        [AMADatabaseQueueProvider sharedInstance].logsEnabled = configuration.areLogsEnabled;
    }];
}

- (void)setPreloadInfo:(AMAAppMetricaPreloadInfo *)preloadInfo
{
    _preloadInfo = preloadInfo;

    if (preloadInfo != nil) {
        AMALogInfo(@"Set custom preload info %@", preloadInfo);
    }
}

// TODO: Observe configuration changes instead of calling this method on every configuration change
- (void)handleConfigurationUpdate
{
    [self execute:^{
        [self.strategiesContainer handleConfigurationUpdate];
    }];
}

- (void)execute:(dispatch_block_t)block
{
    [self.executor execute:block];
}

@end
