
#import "AMAAppMetricaCrashesConfiguration.h"

@implementation AMAAppMetricaCrashesConfiguration

- (instancetype)init 
{
    self = [super init];
    if (self != nil) {
        _autoCrashTracking = YES;
        _probablyUnhandledCrashReporting = NO;
        _ignoredCrashSignals = nil;
        _applicationNotRespondingDetection = NO;
        _applicationNotRespondingWatchdogInterval = 4.0;
        _applicationNotRespondingPingInterval = 0.1;
    }
    return self;
}

- (BOOL)isEqual:(id)object 
{
    if ([object isMemberOfClass:self.class] == NO) {
        return NO;
    }
    
    AMAAppMetricaCrashesConfiguration *config = (AMAAppMetricaCrashesConfiguration *)object;
    
    return (self.autoCrashTracking == config.autoCrashTracking &&
            self.probablyUnhandledCrashReporting == config.probablyUnhandledCrashReporting &&
            [self bothValuesAreNilOrValue:self.ignoredCrashSignals isEqualToValue:config.ignoredCrashSignals] &&
            self.applicationNotRespondingDetection == config.applicationNotRespondingDetection &&
            self.applicationNotRespondingWatchdogInterval == config.applicationNotRespondingWatchdogInterval &&
            self.applicationNotRespondingPingInterval == config.applicationNotRespondingPingInterval);
}

- (NSUInteger)hash
{
    NSUInteger prime = 31;
    NSUInteger result = 1;
    
    result = prime * result + [self.class hash];
    result = prime * result + (self.autoCrashTracking ? 1 : 0);
    result = prime * result + (self.probablyUnhandledCrashReporting ? 1 : 0);
    result = prime * result + [self.ignoredCrashSignals hash];
    result = prime * result + (self.applicationNotRespondingDetection ? 1 : 0);
    result = prime * result + (NSUInteger)(self.applicationNotRespondingWatchdogInterval * 1000);
    result = prime * result + (NSUInteger)(self.applicationNotRespondingPingInterval * 1000);
    
    return result;
}

- (BOOL)bothValuesAreNilOrValue:(id)value isEqualToValue:(id)anotherValue
{
    return (value == nil && anotherValue == nil) || [value isEqual:anotherValue];
}

- (nonnull id)copyWithZone:(nullable NSZone *)zone
{
    AMAAppMetricaCrashesConfiguration *copy = [[[self class] allocWithZone:zone] init];
    if (copy) {
        copy->_autoCrashTracking = _autoCrashTracking;
        copy->_probablyUnhandledCrashReporting = _probablyUnhandledCrashReporting;
        copy->_ignoredCrashSignals = [_ignoredCrashSignals copyWithZone:zone];
        copy->_applicationNotRespondingDetection = _applicationNotRespondingDetection;
        copy->_applicationNotRespondingWatchdogInterval = _applicationNotRespondingWatchdogInterval;
        copy->_applicationNotRespondingPingInterval = _applicationNotRespondingPingInterval;
    }
    return copy;
}

@end

