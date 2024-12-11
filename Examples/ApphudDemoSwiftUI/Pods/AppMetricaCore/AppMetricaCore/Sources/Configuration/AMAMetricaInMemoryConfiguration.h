
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kAMAMetricaLibraryApiKey;
extern NSUInteger const kAMADefaultDispatchPeriodSeconds;
extern NSUInteger const kAMAAutomaticReporterDefaultMaxReportsCount;
extern NSUInteger const kAMAManualReporterDefaultMaxReportsCount;
extern NSUInteger const kAMASessionValidIntervalInSecondsDefault;
extern NSUInteger const kAMAMinSessionTimeoutInSeconds;
extern NSUInteger const kAMAMaxReportsInDatabaseCount;
extern NSUInteger const kAMAMinValueOfMaxReportsInDatabaseCount;
extern NSUInteger const kAMAMaxValueOfMaxReportsInDatabaseCount;
extern NSString *const kAMADefaultStartupHost;
extern BOOL const kAMADefaultRevenueAutoTrackingEnabled;
extern BOOL const kAMADefaultAppOpenTrackingEnabled;

@interface AMAMetricaInMemoryConfiguration : NSObject

@property (atomic, assign) BOOL handleFirstActivationAsUpdate;
@property (atomic, assign) BOOL handleActivationAsSessionStart;
@property (atomic, assign) BOOL sessionsAutoTracking;

@property (atomic, copy) NSString *appVersion;
@property (atomic, assign) uint32_t appBuildNumber;
@property (atomic, copy) NSString *appBuildNumberString;

@property (atomic, assign) NSUInteger batchSize;
@property (atomic, assign) double trimEventsPercent;
@property (atomic, assign) NSUInteger sessionMaxDuration;
@property (atomic, assign) NSUInteger maxProtobufMsgSize;
@property (atomic, assign) NSUInteger backgroundSessionTimeout;
@property (atomic, assign) NSUInteger updateSessionStampInterval;

@property (atomic, assign, readonly) BOOL appMetricaStarted;
@property (atomic, assign, readonly) BOOL appMetricaStartedAnonymously;
@property (atomic, assign, readonly) BOOL appMetricaImplCreated;
@property (atomic, assign, readonly) BOOL externalServicesConfigured;

- (void)markAppMetricaStarted;
- (void)markAppMetricaStartedAnonymously;
- (void)markAppMetricaImplCreated;
- (void)markExternalServicesConfigured;

@property (atomic, copy, readonly) NSArray<NSString *> *additionalStartupHosts;

- (void)addAdditionalStartupHosts:(NSArray *)hosts;

@end

NS_ASSUME_NONNULL_END
