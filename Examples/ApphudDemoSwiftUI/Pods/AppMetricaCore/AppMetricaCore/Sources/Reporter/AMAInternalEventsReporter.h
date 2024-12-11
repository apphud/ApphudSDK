#import <Foundation/Foundation.h>

#import <AppMetricaHostState/AppMetricaHostState.h>

@protocol AMAAsyncExecuting;
@protocol AMAReporterProviding;
@protocol AMAHostStateProviding;

@interface AMAInternalEventsReporter : NSObject <AMAHostStateProviderDelegate>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting>)executor
                reporterProvider:(id<AMAReporterProviding>)reporterProvider;
- (instancetype)initWithExecutor:(id<AMAAsyncExecuting>)executor
                reporterProvider:(id<AMAReporterProviding>)reporterProvider
               hostStateProvider:(id<AMAHostStateProviding>)hostStateProvider;

- (void)reportSchemaInconsistencyWithDescription:(NSString *)inconsistencyDescription;

- (void)reportSearchAdsTokenSuccess;

- (void)reportEventFileNotFoundForEventWithType:(NSUInteger)eventType;

- (void)reportExtensionsReportWithParameters:(NSDictionary *)parameters;
- (void)reportExtensionsReportCollectingException:(NSException *)exception;

- (void)reportSKADAttributionParsingError:(NSDictionary *)parameters;

@end
