
#import <Foundation/Foundation.h>

@class AMAReporterStateStorage;
@class AMAMetricaConfiguration;

NS_ASSUME_NONNULL_BEGIN

@protocol AMAPrivacyTimerStorage <NSObject>
@property (readonly, nonatomic) NSArray<NSNumber *> *retryPeriod;

@property (readonly) BOOL isResendPeriodOutdated;
- (void) privacyEventSent;
@end

@interface AMAMetrikaPrivacyTimerStorage : NSObject<AMAPrivacyTimerStorage>

- (instancetype)initWithReporterMetricaConfiguration:(AMAMetricaConfiguration*)metricaConfiguration
                                        stateStorage:(AMAReporterStateStorage*)stateStorage;

@property (nonnull, atomic, strong, readwrite) AMAMetricaConfiguration *metricaConfiguration;

@property (readonly, nonatomic) NSArray<NSNumber *> *retryPeriod;

@property (readonly) BOOL isResendPeriodOutdated;
- (void) privacyEventSent;

@end

NS_ASSUME_NONNULL_END
