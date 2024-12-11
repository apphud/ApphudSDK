
#import "AMACore.h"
#import "AMAPermissionsConfiguration.h"
#import "AMAMetricaConfiguration.h"
#import "AMAStartupParametersConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"

@implementation AMAPermissionsConfiguration

- (BOOL)collectingEnabled
{
    return [AMAMetricaConfiguration sharedInstance].startup.permissionsCollectingEnabled;
}

- (NSTimeInterval)collectingInterval
{
    AMAMetricaConfiguration *config = [AMAMetricaConfiguration sharedInstance];
    NSNumber *interval = config.startup.permissionsCollectingForceSendInterval ?: @(1 * AMA_DAYS);
    return (NSTimeInterval)(interval).longLongValue;
}

-(NSArray<AMAPermissionKey> *)keys
{
    NSSet *list = [NSSet setWithArray:[AMAMetricaConfiguration sharedInstance].startup.permissionsCollectingList];
    NSMutableSet *allKeys = [NSMutableSet setWithArray:[[self class] allKeys]];
    [allKeys intersectSet:list];
    return allKeys.allObjects;
}

- (NSDate *)lastUpdateDate
{
    return [AMAMetricaConfiguration sharedInstance].persistent.lastPermissionsUpdateDate;
}

- (void)setLastUpdateDate:(NSDate *)lastUpdateDate
{
    [AMAMetricaConfiguration sharedInstance].persistent.lastPermissionsUpdateDate = lastUpdateDate;
}

+ (NSArray<AMAPermissionKey> *)allKeys
{
    return @[
        kAMAPermissionKeyLocationAlways,
        kAMAPermissionKeyLocationWhenInUse,
        kAMAPermissionKeyATTStatus,
    ];
}

@end
