#import <Foundation/Foundation.h>

#import <AppMetricaCore/AppMetricaCore.h>

#import "AMAStartupCompletionObserving.h"

NS_ASSUME_NONNULL_BEGIN

@class AMAMetricaPersistentConfiguration;
@class AMAReporter;
@class AMAStartupParametersConfiguration;

@protocol AMADateProviding;

@interface AMAExternalAttributionController : NSObject <AMAStartupCompletionObserving>

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithReporter:(AMAReporter *)reporter;
- (instancetype)initWithStartupConfiguration:(AMAStartupParametersConfiguration *)startupConfiguration
                     persistentConfiguration:(AMAMetricaPersistentConfiguration *)persistentConfiguration
                                dateProvider:(id<AMADateProviding>)dateProvider
                                    reporter:(AMAReporter *)reporter NS_DESIGNATED_INITIALIZER;

- (void)processAttributionData:(NSDictionary *)data
                        source:(AMAAttributionSource)source
                     onFailure:(nullable void(^)(NSError *error))failure;

@end

NS_ASSUME_NONNULL_END
