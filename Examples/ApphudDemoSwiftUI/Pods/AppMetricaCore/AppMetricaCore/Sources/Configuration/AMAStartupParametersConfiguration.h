
#import <Foundation/Foundation.h>

@protocol AMAKeyValueStoring;
@class AMAPair;

@interface AMAStartupParametersConfiguration : NSObject

@property (nonatomic, strong) NSNumber *retryPolicyMaxIntervalSeconds;
@property (nonatomic, strong) NSNumber *retryPolicyExponentialMultiplier;

@property (nonatomic, strong) NSNumber *serverTimeOffset;
@property (nonatomic, copy) NSString *initialCountry;
@property (nonatomic, copy) NSString *permissionsString;

@property (nonatomic, copy) NSArray *startupHosts;
@property (nonatomic, strong) NSNumber *startupUpdateInterval;
@property (nonatomic, copy) NSArray *reportHosts;
@property (nonatomic, copy) NSString *redirectHost;
@property (nonatomic, copy) NSDictionary<NSString *, NSArray<NSString *> *> *SDKsCustomHosts;

@property (nonatomic, assign) BOOL permissionsCollectingEnabled;
@property (nonatomic, copy) NSArray *permissionsCollectingList;
@property (nonatomic, strong) NSNumber *permissionsCollectingForceSendInterval;

@property (nonatomic, strong) NSNumber *statSendingDisabledReportingInterval;

@property (nonatomic, assign) BOOL extensionsCollectingEnabled;
@property (nonatomic, strong) NSNumber *extensionsCollectingInterval;
@property (nonatomic, strong) NSNumber *extensionsCollectingLaunchDelay;

@property (nonatomic, assign) BOOL locationCollectingEnabled;
@property (nonatomic, assign) BOOL locationVisitsCollectingEnabled;
@property (nonatomic, copy) NSArray *locationHosts;
@property (nonatomic, strong) NSNumber *locationMinUpdateInterval;
@property (nonatomic, strong) NSNumber *locationMinUpdateDistance;
@property (nonatomic, strong) NSNumber *locationRecordsCountToForceFlush;
@property (nonatomic, strong) NSNumber *locationMaxRecordsCountInBatch;
@property (nonatomic, strong) NSNumber *locationMaxAgeToForceFlush;
@property (nonatomic, strong) NSNumber *locationMaxRecordsToStoreLocally;
@property (nonatomic, strong) NSNumber *locationDefaultDesiredAccuracy;
@property (nonatomic, strong) NSNumber *locationDefaultDistanceFilter;
@property (nonatomic, strong) NSNumber *locationAccurateDesiredAccuracy;
@property (nonatomic, strong) NSNumber *locationAccurateDistanceFilter;
@property (nonatomic, strong) NSNumber *locationPausesLocationUpdatesAutomatically;

@property (nonatomic, strong) NSNumber *ASATokenFirstDelay;
@property (nonatomic, strong) NSNumber *ASATokenReportingInterval;
@property (nonatomic, strong) NSNumber *ASATokenEndReportingInterval;
@property (nonatomic, strong) NSArray<AMAPair *> *attributionDeeplinkConditions;

@property (nonatomic, strong) NSNumber *externalAttributionCollectingInterval;

@property (nonatomic, copy) NSArray<NSString *> *appleTrackingHosts;
@property (nonatomic, strong) NSNumber *applePrivacyResendPeriod;
@property (nonatomic, copy) NSArray<NSNumber *> *applePrivacyRetryPeriod;

@property (nonatomic, copy) NSDictionary<NSString *, NSString *> *extendedParameters;

@property (nonatomic, strong, readonly) id<AMAKeyValueStoring> storage;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStorage:(id<AMAKeyValueStoring>)storage;

+ (NSArray<NSString *> *)allKeys;

@end
