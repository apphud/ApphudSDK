
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMALocationRequestParameters.h"
#import "AMAStartupClientIdentifierFactory.h"
#import "AMAStartupClientIdentifier.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaInMemoryConfiguration.h"
#import "AMAAdProvider.h"

@implementation AMALocationRequestParameters

#pragma mark - Public -

+ (NSDictionary *)parametersWithRequestIdentifier:(NSNumber *)requestIdentifier
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [self fillSDKParameters:parameters];
    [self fillAppParameters:parameters];
    [self fillDeviceParameters:parameters];
    [self fillIdentifierParameters:parameters];
    parameters[@"request_id"] = [requestIdentifier stringValue];
    return [parameters copy];
}

#pragma mark - Private -

+ (void)fillAppParameters:(NSMutableDictionary *)parameters
{
    AMAMetricaConfiguration *metricaConfiguration = [AMAMetricaConfiguration sharedInstance];
    parameters[@"app_version_name"] = metricaConfiguration.inMemory.appVersion;
    parameters[@"app_build_number"] = [NSString stringWithFormat:@"%ld", (long)metricaConfiguration.inMemory.appBuildNumber];
    parameters[@"app_platform"] = [AMAPlatformDescription OSName];
    parameters[@"app_framework"] = [AMAPlatformDescription appFramework];
    parameters[@"app_id"] = [AMAPlatformDescription appID];
}

+ (void)fillDeviceParameters:(NSMutableDictionary *)parameters
{
    parameters[@"os_version"] = [AMAPlatformDescription OSVersion];
    parameters[@"os_api_level"] = [@([AMAPlatformDescription OSAPILevel]) stringValue];
    parameters[@"device_type"] = [AMAPlatformDescription deviceType];
    parameters[@"is_rooted"] = [AMAPlatformDescription isDeviceRooted] ? @"1" : @"0";
}

+ (void)fillIdentifierParameters:(NSMutableDictionary *)parameters
{
    AMAStartupClientIdentifier *identifier = [AMAStartupClientIdentifierFactory startupClientIdentifier];
    parameters[@"uuid"] = identifier.UUID;
    parameters[@"deviceid"] = identifier.deviceID ?: @"";
    parameters[@"ifv"] = identifier.IFV;
}

+ (void)fillSDKParameters:(NSMutableDictionary *)parameters
{
    parameters[@"encrypted_request"] = @"1";
    parameters[@"analytics_sdk_version_name"] = [AMAPlatformDescription SDKVersionName];
    parameters[@"analytics_sdk_build_type"] = [AMAPlatformDescription SDKBuildType];
    parameters[@"analytics_sdk_build_number"] = [NSString stringWithFormat:@"%ld", (long)[AMAPlatformDescription SDKBuildNumber]];
}

@end
