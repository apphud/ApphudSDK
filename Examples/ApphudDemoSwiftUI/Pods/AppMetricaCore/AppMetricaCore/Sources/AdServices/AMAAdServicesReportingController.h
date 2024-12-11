
#import <Foundation/Foundation.h>

@class AMAReporterStateStorage;
@class AMAAdServicesDataProvider;
@class AMAMetricaConfiguration;

@interface AMAAdServicesReportingController : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithApiKey:(NSString *)apiKey
               reporterStorage:(AMAReporterStateStorage *)reporterStorage
                 configuration:(AMAMetricaConfiguration *)configuration
                  dataProvider:(AMAAdServicesDataProvider *)dataProvider;

- (instancetype)initWithApiKey:(NSString *)key reporterStateStorage:(AMAReporterStateStorage *)storage;

- (void)reportTokenIfNeeded;

@end
