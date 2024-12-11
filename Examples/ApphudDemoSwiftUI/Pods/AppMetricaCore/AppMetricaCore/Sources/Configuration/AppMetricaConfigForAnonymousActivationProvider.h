
#import <Foundation/Foundation.h>

@class AppMetricaDefaultAnonymousConfigProvider;
@class AMAMetricaPersistentConfiguration;
@class AMAAppMetricaConfiguration;
@class AMAFirstActivationDetector;

@interface AppMetricaConfigForAnonymousActivationProvider : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStorage:(AMAMetricaPersistentConfiguration *)persistent;
- (instancetype)initWithStorage:(AMAMetricaPersistentConfiguration *)persistent
                defaultProvider:(AppMetricaDefaultAnonymousConfigProvider *)defaultProvider
        firstActivationDetector:(AMAFirstActivationDetector *)firstActivationDetector;

- (AMAAppMetricaConfiguration *)configuration;

@end
