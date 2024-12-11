
#import "AMAStartupParameters.h"
#import "AMAStartupClientIdentifier.h"
#import "AMAStartupClientIdentifierFactory.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAStartupParametersConfiguration.h"
#import <AppMetricaPlatform/AppMetricaPlatform.h>

@implementation AMAStartupParameters

#pragma mark - Public -

+ (NSDictionary *)parameters
{
    NSMutableDictionary *parameters = [NSMutableDictionary dictionary];
    [self fillSDKParameters:parameters];
    [self fillAppParameters:parameters];
    [self fillDeviceParameters:parameters];
    [self fillIdentifierParameters:parameters];
    [self fillFeatureParameters:parameters];
    return [parameters copy];
}

#pragma mark - Private -

+ (void)fillAppParameters:(NSMutableDictionary *)parameters
{
    parameters[@"app_platform"] = [AMAPlatformDescription appPlatform];
    parameters[@"app_debuggable"] = [AMAPlatformDescription appDebuggable] ? @"1" : @"0";
    parameters[@"app_id"] = [AMAPlatformDescription appID];
    parameters[@"locale"] = [AMAPlatformLocaleState fullLocaleIdentifier];
    NSString *initialCountry = [AMAMetricaConfiguration sharedInstance].startup.initialCountry;
    if (initialCountry.length != 0) {
        parameters[@"country_init"] = initialCountry;
    }
}

+ (void)fillDeviceParameters:(NSMutableDictionary *)parameters
{
    parameters[@"manufacturer"] = [AMAPlatformDescription manufacturer];
    parameters[@"model"] = [AMAPlatformDescription model];
    parameters[@"os_version"] = [AMAPlatformDescription OSVersion];
    parameters[@"screen_width"] = [AMAPlatformDescription screenWidth];
    parameters[@"screen_height"] = [AMAPlatformDescription screenHeight];
    parameters[@"screen_dpi"] = [AMAPlatformDescription screenDPI];
    parameters[@"scalefactor"] = [AMAPlatformDescription scalefactor];
    parameters[@"device_type"] = [AMAPlatformDescription deviceType];
}

+ (void)fillIdentifierParameters:(NSMutableDictionary *)parameters
{
    AMAStartupClientIdentifier *identifier = [AMAStartupClientIdentifierFactory startupClientIdentifier];
    NSDictionary *startupParameters = [identifier startupParameters];
    NSSet *whiteList = [NSSet setWithArray:@[
                                            kAMAStartupParameterDeviceID,
                                            kAMAStartupParameterUUID,
                                            kAMAStartupParameterDeviceIDForVendor,
                                            ]];
    NSDictionary *filteredStartupParameters = [AMACollectionUtilities filteredDictionary:startupParameters
                                                                                withKeys:whiteList];
    [parameters addEntriesFromDictionary:filteredStartupParameters];
    
    parameters[kAMAStartupParameterDeviceID] = parameters[kAMAStartupParameterDeviceID] ?: @"";
}

+ (void)fillFeatureParameters:(NSMutableDictionary *)parameters
{
    NSArray *features = @[
        @"ea",
        @"exc",
        @"s",
        @"sc",
        @"pc",
        @"vc",
        @"dlch",
    ];
    [parameters addEntriesFromDictionary:@{
        @"query_hosts": @"2",
        @"queries": @"1",
        @"b": @"1",
        @"s": @"1",
        @"permissions": @"1",
        @"stat_sending": @"1",
        @"exc": @"1",
        @"flc": @"1",
        @"slc" : @"1",
        @"rp" : @"1",
        @"pc" : @"1",
        @"asa" : @"1",
        @"at" : @"1",
        // skad conversion value
        @"scv" :@"1",
        @"scm": @"1",
        @"srm": @"1",
        @"senm": @"1",
        // skad convesion value end
        @"su": @"1",
        @"exta" : @"1",
        @"features": [features componentsJoinedByString:@","],
    }];
    if (self.isFirstRequest) {
        parameters[@"detect_locale"] = @"1";
    }
}

+ (void)fillSDKParameters:(NSMutableDictionary *)parameters
{
    parameters[@"protocol_version"] = @"2";
    parameters[@"analytics_sdk_version_name"] = [AMAPlatformDescription SDKVersionName];
    parameters[@"atc"] = @"1";
}

+ (BOOL)isFirstRequest
{
    return [AMAMetricaConfiguration sharedInstance].persistent.hadFirstStartup == NO;
}

@end
