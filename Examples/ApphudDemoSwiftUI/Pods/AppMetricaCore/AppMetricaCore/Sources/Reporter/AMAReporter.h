
#import <Foundation/Foundation.h>
#import "AMAJSControlling.h"
#import "AMACore.h"

@protocol AMACancelableExecuting;
@class AMAReporterStorage;
@class AMAEventBuilder;
@class AMAInternalEventsReporter;
@class AMAErrorModel;
@class AMAStartEventValueProvider;
@class AMAECommerceSerializer;
@class AMAECommerceTruncator;
@class AMARevenueInfoModel;
@class AMAAdServicesDataProvider;
@class AMAAttributionChecker;
@protocol AMAAsyncExecuting;
@class AMASessionExpirationHandler;
@class AMACustomEventParameters;
@class AMAAdProvider;
@class AMAPrivacyTimer;
@class AMAExternalAttributionSerializer;

@protocol AMAReporterDelegate <NSObject>

- (void)sendEventsBufferWithApiKey:(NSString *)apiKey;

@end

@interface AMAReporter : NSObject <AMAAppMetricaReporting, AMAAppMetricaExtendedReporting
#if !TARGET_OS_TV
, AMAJSReporting
#endif
>

@property (nonatomic, strong, readonly) id<AMACancelableExecuting, AMASyncExecuting> executor;
@property (nonatomic, copy, readonly) NSString *apiKey;
@property (nonatomic, strong, readonly) AMAInternalEventsReporter *internalReporter;
@property (nonatomic, weak) id<AMAReporterDelegate> delegate;
@property (nonatomic, strong, readonly) AMAReporterStorage *reporterStorage;
@property (nonatomic, assign, readonly) BOOL main;
@property (nonatomic, strong, readwrite) AMAAttributionChecker *attributionChecker;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithApiKey:(NSString *)apiKey
                          main:(BOOL)main
               reporterStorage:(AMAReporterStorage *)reporterStorage
                  eventBuilder:(AMAEventBuilder *)eventBuilder
              internalReporter:(AMAInternalEventsReporter *)internalReporter
      attributionCheckExecutor:(id<AMAAsyncExecuting>)attributionCheckExecutor;

- (instancetype)initWithApiKey:(NSString *)apiKey
                          main:(BOOL)main
               reporterStorage:(AMAReporterStorage *)reporterStorage
                  eventBuilder:(AMAEventBuilder *)eventBuilder
              internalReporter:(AMAInternalEventsReporter *)internalReporter
                      executor:(id<AMACancelableExecuting, AMASyncExecuting>)executor
      attributionCheckExecutor:(id<AMAAsyncExecuting>)attributionCheckExecutor
           eCommerceSerializer:(AMAECommerceSerializer *)eCommerceSerializer
            eCommerceTruncator:(AMAECommerceTruncator *)eCommerceTruncator
                    adServices:(AMAAdServicesDataProvider *)adServices
 externalAttributionSerializer:(AMAExternalAttributionSerializer *)externalAttributionSerializer
      sessionExpirationHandler:(AMASessionExpirationHandler *)sessionExpirationHandler
                    adProvider:(AMAAdProvider *)adProvider
                  privacyTimer:(AMAPrivacyTimer *)privacyTimer;

- (void)setupWithOnStorageRestored:(dispatch_block_t)onStorageRestored
                   onSetupComplete:(dispatch_block_t)onSetupComplete;
- (void)shutdown;
- (void)start;

- (void)updateAPIKey:(NSString *)apiKey;

- (void)restartPrivacyTimer;

- (void)reportFirstEventIfNeeded;
- (void)reportOpenEvent:(NSDictionary *)parameters
          reattribution:(BOOL)reattribution
              onFailure:(void (^)(NSError *error))onFailure;
- (void)reportPermissionsEventWithPermissions:(NSString *)permissions onFailure:(void (^)(NSError *error))onFailure;
- (void)reportCleanupEvent:(NSDictionary *)parameters onFailure:(void (^)(NSError *error))onFailure;
- (void)reportASATokenEventWithParameters:(NSDictionary *)parameters onFailure:(void (^)(NSError *error))onFailure;
- (void)reportAutoRevenue:(AMARevenueInfoModel *)revenueInfoModel onFailure:(void (^)(NSError *))onFailure;
- (void)reportAttributionEventWithName:(NSString *)name value:(NSDictionary *)value;
- (void)reportExternalAttribution:(NSDictionary *)attribution
                           source:(AMAAttributionSource)source
                        onFailure:(void (^)(NSError *error))onFailure;

@end
