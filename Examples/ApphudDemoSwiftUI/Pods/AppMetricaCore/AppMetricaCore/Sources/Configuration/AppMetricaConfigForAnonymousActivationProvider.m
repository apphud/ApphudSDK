
#import "AppMetricaConfigForAnonymousActivationProvider.h"
#import "AppMetricaDefaultAnonymousConfigProvider.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAFirstActivationDetector.h"
#import "AMAFirstActivationDetector.h"

@interface AppMetricaConfigForAnonymousActivationProvider ()

@property (nonatomic, strong, readwrite) AppMetricaDefaultAnonymousConfigProvider *defaultProvider;
@property (nonatomic, strong, readwrite) AMAMetricaPersistentConfiguration *persistent;
@property (nonatomic, strong, readwrite) AMAFirstActivationDetector *firstActivationDetector;

@end

@implementation AppMetricaConfigForAnonymousActivationProvider

- (instancetype)initWithStorage:(AMAMetricaPersistentConfiguration *)persistent
{
    return [self initWithStorage:persistent
                 defaultProvider:[[AppMetricaDefaultAnonymousConfigProvider alloc] init]
         firstActivationDetector:[[AMAFirstActivationDetector alloc] init]];
}

- (instancetype)initWithStorage:(AMAMetricaPersistentConfiguration *)persistent
                defaultProvider:(AppMetricaDefaultAnonymousConfigProvider *)defaultProvider
        firstActivationDetector:(AMAFirstActivationDetector *)firstActivationDetector
{
    self = [super init];
    if (self != nil) {
        _defaultProvider = defaultProvider;
        _persistent = persistent;
        _firstActivationDetector = firstActivationDetector;
    }
    return self;
}

- (AMAAppMetricaConfiguration *)configuration
{
    AMAAppMetricaConfiguration *configuration = self.persistent.appMetricaClientConfiguration;
    
    if (configuration == nil) {
        configuration = [self.defaultProvider configuration];
        if ([self.firstActivationDetector isFirstLibraryReporterActivation] == NO) {
            configuration.handleFirstActivationAsUpdate = true;
        }
    }
    return configuration;
}

@end
