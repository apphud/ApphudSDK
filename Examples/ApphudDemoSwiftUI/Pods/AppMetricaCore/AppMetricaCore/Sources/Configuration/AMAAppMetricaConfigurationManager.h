
#import <Foundation/Foundation.h>

@class AMAAppMetricaConfiguration;
@class AMAReporterConfiguration;
@class AMAMetricaConfiguration;
@class AMALocationManager;
@class AMADataSendingRestrictionController;
@class AMAAppMetricaPreloadInfo;
@class AMADispatchStrategiesContainer;
@protocol AMAAsyncExecuting;
@protocol AMASyncExecuting;
@class AppMetricaConfigForAnonymousActivationProvider;
@class AMAFirstActivationDetector;

@interface AMAAppMetricaConfigurationManager : NSObject

@property (nonatomic, copy) AMAAppMetricaPreloadInfo *preloadInfo;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting, AMASyncExecuting>)executor
             strategiesContainer:(AMADispatchStrategiesContainer *)strategiesContainer
         firstActivationDetector:(AMAFirstActivationDetector *)firstActivationDetector;

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting, AMASyncExecuting>)executor
             strategiesContainer:(AMADispatchStrategiesContainer *)strategiesContainer
            metricaConfiguration:(AMAMetricaConfiguration *)metricaConfiguration
                 locationManager:(AMALocationManager *)locationManager
           restrictionController:(AMADataSendingRestrictionController *)restrictionController
         anonymousConfigProvider:(AppMetricaConfigForAnonymousActivationProvider *)anonymousConfigProvider;


- (void)updateMainConfiguration:(AMAAppMetricaConfiguration *)configuration;
- (void)updateReporterConfiguration:(AMAReporterConfiguration *)configuration;
- (AMAAppMetricaPreloadInfo *)preloadInfo;
- (AMAAppMetricaConfiguration *)anonymousConfiguration;

@end
