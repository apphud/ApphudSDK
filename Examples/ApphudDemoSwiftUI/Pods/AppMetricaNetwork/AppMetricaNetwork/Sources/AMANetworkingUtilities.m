
#import "AMANetworkCore.h"
#import <AppMetricaNetwork/AppMetricaNetwork.h>
#import <AppMetricaPlatform/AppMetricaPlatform.h>

@implementation AMANetworkingUtilities

+ (void)addUserAgentHeadersToDictionary:(NSMutableDictionary *)dictionary
{
    dictionary[@"User-Agent"] = [AMAPlatformDescription SDKUserAgent];
}

+ (void)addSendTimeHeadersToDictionary:(NSMutableDictionary *)dictionary date:(NSDate *)date
{
    NSString *timestamp = [AMATimeUtilities timestampForDate:date];
    NSTimeZone *zone = [NSTimeZone systemTimeZone];
    NSString *differenceString = [NSString stringWithFormat:@"%d", (int)[zone secondsFromGMT]];

    NSDictionary *sendTimeHeaders = @{ @"Send-Timestamp" : timestamp, @"Send-Timezone" : differenceString };
    [dictionary addEntriesFromDictionary:sendTimeHeaders];
}

@end
