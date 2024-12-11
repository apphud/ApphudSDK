
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import "AMAPersistentTimeoutConfiguration.h"
#import "AMATimeoutConfiguration.h"

AMAHostType const AMAStartupHostType = @"startup.hosts";
AMAHostType const AMAReportHostType = @"report.hosts";
AMAHostType const AMALocationHostType = @"location.collecting.hosts";
AMAHostType const AMATrackingHostType = @"apple_tracking.hosts";

static NSString *const kDateStorageKey = @"date";
static NSString *const kCountStorageKey = @"count";

@implementation AMAPersistentTimeoutConfiguration

- (instancetype)initWithStorage:(id<AMAKeyValueStoring>)storage
{
    self = [super init];
    if (self != nil) {
        _storage = storage;
    }
    return self;
}

#pragma mark - Public -

- (AMATimeoutConfiguration *)timeoutConfigForHostType:(AMAHostType)hostType
{
    NSString *timestampKey = [self key:kDateStorageKey forHostType:hostType];
    NSString *countKey = [self key:kCountStorageKey forHostType:hostType];

    AMATimeoutConfiguration *timeoutConfig = nil;
    @synchronized (self) {
        NSDate *timeStamp = [self.storage dateForKey:timestampKey error:nil];
        NSNumber *count = [self.storage longLongNumberForKey:countKey error:nil];
        if (count != nil || timeStamp != nil) {
            timeoutConfig = [[AMATimeoutConfiguration alloc] initWithLimitDate:timeStamp
                                                                         count:[count unsignedIntegerValue]];
        }
    }

    return timeoutConfig;
}

- (void)saveTimeoutConfig:(AMATimeoutConfiguration *)timeoutConfig forHostType:(AMAHostType)hostType
{
    NSString *timestampKey = [self key:kDateStorageKey forHostType:hostType];
    NSString *countKey = [self key:kCountStorageKey forHostType:hostType];

    @synchronized (self) {
        [self.storage saveDate:timeoutConfig.limitDate forKey:timestampKey error:nil];
        [self.storage saveLongLongNumber:timeoutConfig == nil ? nil : @((long long)timeoutConfig.count)
                                  forKey:countKey
                                   error:nil];
    }
}

#pragma mark - Private -

- (NSString *)key:(NSString *)key forHostType:(AMAHostType)hostType
{
    return [NSString stringWithFormat:@"%@.timeout.%@", hostType, key];
}

@end
