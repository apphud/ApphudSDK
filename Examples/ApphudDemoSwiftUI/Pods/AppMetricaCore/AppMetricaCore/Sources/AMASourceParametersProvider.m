
#import "AMASourceParametersProvider.h"
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import <AppMetricaPlatform/AppMetricaPlatform.h>

@implementation AMASourceParametersProvider

+ (NSDictionary *)sourceParameters:(NSString *)apiKey
{
    NSMutableDictionary *sourceParameters = [NSMutableDictionary dictionary];
    sourceParameters[@"source_api_key"] = apiKey;
    sourceParameters[@"source_app_id"] = [AMAPlatformDescription appID];
    return [AMACollectionUtilities dictionaryByRemovingEmptyStringValuesForDictionary:sourceParameters];
}

@end
