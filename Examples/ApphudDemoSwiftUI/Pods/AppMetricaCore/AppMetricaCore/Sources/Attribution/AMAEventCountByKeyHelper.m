
#import "AMACore.h"
#import "AMAEventCountByKeyHelper.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"

@implementation AMAEventCountByKeyHelper

- (NSUInteger)getCountForKey:(NSString *)key
{
    NSDictionary<NSString *, NSNumber *> *map = [AMAMetricaConfiguration sharedInstance].persistent.eventCountsByKey;
    NSUInteger result = map[key].unsignedIntegerValue;
    AMALogInfo(@"For %@ result is %lu. Full map: %@", key, (unsigned long) result, map);
    return result;
}

- (void)setCount:(NSUInteger)count forKey:(NSString *)key
{
    NSDictionary<NSString *, NSNumber *> *map = [AMAMetricaConfiguration sharedInstance].persistent.eventCountsByKey;
    NSMutableDictionary *newMap;
    if (map != nil) {
        newMap = [map mutableCopy];
    } else {
        newMap = [[NSMutableDictionary alloc] init];
    }
    newMap[key] = @(count);
    [AMAMetricaConfiguration sharedInstance].persistent.eventCountsByKey = [newMap copy];
}

@end
