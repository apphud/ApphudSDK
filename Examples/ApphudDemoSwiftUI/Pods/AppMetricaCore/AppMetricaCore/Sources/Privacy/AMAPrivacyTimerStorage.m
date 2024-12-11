
#import "AMAPrivacyTimerStorage.h"
#import "AMAReporterStateStorage.h"
#import "AMAMetricaConfiguration.h"
#import "AMAReporterStateStorage.h"
#import "AMAStartupParametersConfiguration.h"

@interface AMAMetrikaPrivacyTimerStorage ()

@property (nonnull, nonatomic, strong, readonly) AMAReporterStateStorage *stateStorage;

@end

@implementation AMAMetrikaPrivacyTimerStorage

- (nonnull instancetype)initWithReporterMetricaConfiguration:(nonnull AMAMetricaConfiguration *)metricaConfiguration 
                                                stateStorage:(nonnull AMAReporterStateStorage *)stateStorage 
{
    self = [super init];
    if (self) {
        _metricaConfiguration = metricaConfiguration;
        _stateStorage = stateStorage;
    }
    return self;
}

- (NSArray<NSNumber *> *)retryPeriod
{
    NSArray<NSNumber *> *result = self.metricaConfiguration.startup.applePrivacyRetryPeriod;
    if (result == nil) {
        result = @[@(10), @(10), @(10), @(30), @(60), @(120), @(240), @(300)];
    }
    return result;
}

- (BOOL)isResendPeriodOutdated
{
    NSDate *prevSendDate = self.stateStorage.privacyLastSendDate;
    
    NSNumber *resentTimeoutNumber = self.metricaConfiguration.startup.applePrivacyResendPeriod;
    NSTimeInterval resentTimeout = resentTimeoutNumber != nil ? [resentTimeoutNumber doubleValue] : 259200;
 
    BOOL isOutdated = prevSendDate.timeIntervalSince1970 + resentTimeout < [NSDate date].timeIntervalSince1970;
    
    return isOutdated;
}

- (void)privacyEventSent
{
    [self.stateStorage markLastPrivacySentNow];
}


@end
