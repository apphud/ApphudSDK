
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@implementation AMANumberUtilities

+ (NSUInteger)unsignedIntegerForNumber:(NSNumber *)number defaultValue:(NSUInteger)defaultValue
{
    return number == nil ? defaultValue : [number unsignedIntegerValue];
}

+ (double)doubleWithNumber:(NSNumber *)value defaultValue:(double)defaultValue
{
    return value != nil ? value.doubleValue : defaultValue;
}

+ (BOOL)boolForNumber:(NSNumber *)number defaultValue:(BOOL)defaultValue
{
    return number == nil ? defaultValue : [number boolValue];
}

@end
