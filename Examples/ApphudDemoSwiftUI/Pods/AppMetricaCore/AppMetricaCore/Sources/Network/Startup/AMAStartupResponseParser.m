
#import "AMACore.h"
#import "AMAStartupResponseParser.h"
#import "AMAStartupResponseEncoderFactory.h"
#import "AMAMetricaConfiguration.h"
#import "AMAStartupPermissionSerializer.h"
#import "AMAStartupParametersConfiguration.h"
#import "AMAPair.h"
#import "AMAAttributionModelParser.h"

static NSString *const kAMAStartupResponseEnabledKey = @"enabled";
static NSString *const kAMAStartupResponseURLsKey = @"urls";

@interface AMAStartupResponseParser ()

@property (nonatomic, strong, readonly) AMAAttributionModelParser *attributionModelParser;

@end

@implementation AMAStartupResponseParser

- (instancetype)init
{
    return [self initWithAttributionModelParser:[[AMAAttributionModelParser alloc] init]];
}

- (instancetype)initWithAttributionModelParser:(AMAAttributionModelParser *)attributionModelParser
{
    self = [super init];
    if (self != nil) {
        _attributionModelParser = attributionModelParser;
    }
    return self;
}

#pragma mark - Public -
- (AMAStartupResponse *)startupResponseWithHTTPResponse:(NSHTTPURLResponse *)HTTPResponse
                                                   data:(NSData *)data
                                                  error:(NSError **)error
{
    AMAStartupResponse *response = nil;
    NSDictionary *parsedData = [self deserializeResponse:HTTPResponse data:data error:error];
    if (parsedData != nil) {
        AMAStartupParametersConfiguration *configuration = [[AMAMetricaConfiguration sharedInstance] startupCopy];
        response = [[AMAStartupResponse alloc] initWithStartupConfiguration:configuration];
        response.configuration.serverTimeOffset = [self serverTimeOffsetWithResponse:HTTPResponse];
        NSString *const kAMAStartupResponseValueKey = @"value";

        response.deviceID = [self trimmedString:parsedData[@"device_id"][kAMAStartupResponseValueKey]];
        response.deviceIDHash = [self trimmedString:parsedData[@"device_id"][@"hash"]];
        response.attributionModelConfiguration = [self.attributionModelParser parse:parsedData[@"skad_conversion_value"]];

        NSDictionary *replyPolicy = parsedData[@"retry_policy"];
        configuration.retryPolicyMaxIntervalSeconds = replyPolicy[@"max_interval_seconds"];
        configuration.retryPolicyExponentialMultiplier = replyPolicy[@"exponential_multiplier"];

        NSString *const kAMAStartupResponseArrayKey = @"list";

        NSString *const kAMAStartupRedirectHostKey = @"redirect";
        NSString *const kAMAStartupStartupHostsKey = @"startup";
        NSString *const kAMAStartupReportHostsKey = @"report";
        NSString *const kAMAStartupLocationHostsKey = @"location";

        NSArray *const kAMAStartupKnowHostsKeys = @[
            kAMAStartupRedirectHostKey,
            kAMAStartupStartupHostsKey,
            kAMAStartupReportHostsKey,
            kAMAStartupLocationHostsKey,
        ];

        NSDictionary *hosts = parsedData[@"query_hosts"][kAMAStartupResponseArrayKey];
        configuration.redirectHost = [self urlFromHostsDictionary:hosts byKey:kAMAStartupRedirectHostKey];
        configuration.startupHosts = hosts[kAMAStartupStartupHostsKey][kAMAStartupResponseURLsKey];
        configuration.reportHosts = hosts[kAMAStartupReportHostsKey][kAMAStartupResponseURLsKey];
        configuration.locationHosts = hosts[kAMAStartupLocationHostsKey][kAMAStartupResponseURLsKey];
        configuration.SDKsCustomHosts = [self URLsFromHostsDictionary:hosts exceptKeys:kAMAStartupKnowHostsKeys];
        configuration.appleTrackingHosts = hosts[@"apple_tracking"][@"urls"];

        NSDictionary *statSending = parsedData[@"stat_sending"];
        configuration.statSendingDisabledReportingInterval = statSending[@"disabled_reporting_interval_seconds"];

        NSDictionary *extensionsCollecting = parsedData[@"extensions_collecting"];
        configuration.extensionsCollectingInterval = extensionsCollecting[@"min_collecting_interval_seconds"];
        configuration.extensionsCollectingLaunchDelay = extensionsCollecting[@"min_collecting_delay_after_launch_seconds"];

        NSDictionary *locationCollecting = parsedData[@"foreground_location_collection"];
        configuration.locationCollectingEnabled = locationCollecting != nil;
        if (configuration.locationCollectingEnabled) {
            configuration.locationMinUpdateInterval = locationCollecting[@"min_update_interval_seconds"];
            configuration.locationMinUpdateDistance = locationCollecting[@"min_update_distance_meters"];
            configuration.locationRecordsCountToForceFlush = locationCollecting[@"records_count_to_force_flush"];
            configuration.locationMaxRecordsCountInBatch = locationCollecting[@"max_records_count_in_batch"];
            configuration.locationMaxAgeToForceFlush = locationCollecting[@"max_age_seconds_to_force_flush"];
            configuration.locationMaxRecordsToStoreLocally = locationCollecting[@"max_records_to_store_locally"];
        }

        NSDictionary *systemLocationConfig = parsedData[@"system_location_config"];
        if (systemLocationConfig != nil) {
            configuration.locationDefaultDesiredAccuracy = systemLocationConfig[@"default_desired_accuracy"];
            configuration.locationDefaultDistanceFilter = systemLocationConfig[@"default_distance_filter"];
            configuration.locationAccurateDesiredAccuracy = systemLocationConfig[@"accurate_desired_accuracy"];
            configuration.locationAccurateDistanceFilter = systemLocationConfig[@"accurate_distance_filter"];
            configuration.locationPausesLocationUpdatesAutomatically =
                systemLocationConfig[@"pauses_location_updates_automatically"];
        }

        NSDictionary *permissionsConfig = parsedData[@"permissions_collecting"];
        if (permissionsConfig != nil) {
            configuration.permissionsCollectingForceSendInterval = permissionsConfig[@"force_send_interval_seconds"];
            configuration.permissionsCollectingList = [self permissionsListForArray:permissionsConfig[@"list"]];
        }

        NSDictionary *ASATokenConfig = parsedData[@"asa_token_reporting"];
        if (ASATokenConfig != nil) {
            configuration.ASATokenFirstDelay = ASATokenConfig[@"first_delay_seconds"];
            configuration.ASATokenReportingInterval = ASATokenConfig[@"reporting_interval_seconds"];
            configuration.ASATokenEndReportingInterval = ASATokenConfig[@"end_reporting_interval_seconds"];
        }

        NSDictionary *attribution = parsedData[@"attribution"];
        if (attribution != nil) {
            configuration.attributionDeeplinkConditions =
                [self deeplinkConditionsForArray:attribution[@"deeplink_conditions"]];
        }
        
        NSDictionary *startupUpdate = parsedData[@"startup_update"];
        if (startupUpdate != nil) {
            configuration.startupUpdateInterval = startupUpdate[@"interval_seconds"];
        }

        NSDictionary *features = parsedData[@"features"][kAMAStartupResponseArrayKey];

        configuration.extensionsCollectingEnabled =
            [self enabledPropertyValueFromDictionary:features[@"extensions_collecting"]];
        configuration.locationVisitsCollectingEnabled =
            [self enabledPropertyValueFromDictionary:features[@"visits_collecting"]];
        configuration.permissionsCollectingEnabled =
            [self enabledPropertyValueFromDictionary:features[@"permissions_collecting"]];

        configuration.initialCountry = [self countryFromDictionary:parsedData[@"locale"]];

        NSArray *permissions = parsedData[@"permissions"][kAMAStartupResponseArrayKey];
        NSDictionary *permissionsDictionary = [AMAStartupPermissionSerializer permissionsWithArray:permissions];
        configuration.permissionsString =
            [AMAStartupPermissionSerializer JSONStringWithPermissions:permissionsDictionary];
        
        NSDictionary *appleTrackingConfig = parsedData[@"apple_tracking_config"];
        configuration.applePrivacyResendPeriod = appleTrackingConfig[@"event_apple_privacy_resend_period"];
        configuration.applePrivacyRetryPeriod = appleTrackingConfig[@"event_apple_privacy_retry_periods"];
        
        NSDictionary *externalAttribution = parsedData[@"external_attribution"];
        configuration.externalAttributionCollectingInterval = externalAttribution[@"collecting_interval_seconds"];
        
        NSMutableDictionary *extendedParameters = [NSMutableDictionary dictionary];
        NSArray *extendedKeys = @[@"get_ad", @"report_ad"];
        for (NSString *key in extendedKeys) {
            extendedParameters[key] = [self urlFromHostsDictionary:hosts byKey:key];
        }
        configuration.extendedParameters = extendedParameters;
    }
    return response;
}

- (NSDictionary *)extendedStartupResponseWithHTTPResponse:(NSHTTPURLResponse *)HTTPResponse
                                                     data:(NSData *)data
                                                    error:(NSError **)error
{
    return [self deserializeResponse:HTTPResponse data:data error:error];
}

#pragma mark - Deserialization -

- (NSData *)decryptedDataForResponse:(NSHTTPURLResponse *)response data:(NSData *)data error:(NSError **)error
{
    NSData *decryptedData = nil;
    if ([response.allHeaderFields[@"Content-Encoding"] isEqual:@"encrypted"]) {
        id<AMADataEncoding> encoder = [AMAStartupResponseEncoderFactory encoder];
        decryptedData = [encoder decodeData:data error:error];
    }
    else {
        decryptedData = data;
    }
    return decryptedData;
}

- (NSDictionary *)deserializeResponse:(NSHTTPURLResponse *)response data:(NSData *)data error:(NSError **)error
{
    NSDictionary *parsedData = nil;

    if (data != nil) {
        NSData *decryptedData = [self decryptedDataForResponse:response data:data error:error];
        if (decryptedData != nil) {
            parsedData = [NSJSONSerialization JSONObjectWithData:decryptedData options:0 error:error];
            if (parsedData == nil) {
                AMALogWarn(@"Failed to deserialize startup JSON: %@", error != NULL ? *error : nil);
            }
        }
        else {
            AMALogWarn(@"Failed to decrypt startup: %@", error != NULL ? *error : nil);
        }
    }
    else {
        AMALogWarn(@"No startup data received");
    }
    return parsedData;
}

#pragma mark - Helpers -

- (NSString *)countryFromDictionary:(NSDictionary *)localeDictionary
{
    if (localeDictionary == nil) {
        return nil;
    }
    NSDictionary *countryDictionary = localeDictionary[@"country"];
    BOOL reliable = [countryDictionary[@"reliable"] boolValue];
    return reliable ? countryDictionary[@"value"] : nil;
}

- (BOOL)enabledPropertyValueFromDictionary:(NSDictionary *)dictionary
{
    return [[self enabledPropertyFromDictionary:dictionary] boolValue];
}

- (NSNumber *)enabledPropertyFromDictionary:(NSDictionary *)dictionary
{
    id value = dictionary[kAMAStartupResponseEnabledKey];
    if ([value isKindOfClass:NSNumber.class]) {
        return value;
    }
    else {
        return nil;
    }
}

- (NSString *)urlFromHostsDictionary:(NSDictionary *)hosts byKey:(NSString *)key
{
    NSString *url = [hosts[key][kAMAStartupResponseURLsKey] firstObject];
    return [self validatedURL:url];
}

- (NSDictionary *)URLsFromHostsDictionary:(NSDictionary *)hosts exceptKeys:(NSArray<NSString *> *)keys
{
    NSMutableArray *filteredKeys = hosts.allKeys.mutableCopy;
    [filteredKeys removeObjectsInArray:keys];
    NSDictionary *filteredDictionary = [hosts dictionaryWithValuesForKeys:filteredKeys];
    __weak typeof(self) weakSelf = self;
    
    return [AMACollectionUtilities compactMapValuesOfDictionary:filteredDictionary
                                                      withBlock:^id(id key, NSDictionary *value) {
        if ([value isKindOfClass:NSDictionary.class]) {
            NSArray *URLs = value[kAMAStartupResponseURLsKey];
            if ([URLs isKindOfClass:NSArray.class]) {
                return [AMACollectionUtilities mapArray:URLs
                                              withBlock:^id(id item) { return [weakSelf validatedURL:item]; }];
            }
        }
        return nil;
    }];
}

- (NSString *)urlFromQueriesDictionary:(NSDictionary *)hosts byKey:(NSString *)key
{
    NSString *url = hosts[key][@"url"];
    return [self validatedURL:url];
}

- (NSString *)validatedURL:(NSString *)url
{
    NSString *validatedURL = @"";
    NSString *trimmedURL = [self trimmedString:url];
    if (trimmedURL.length != 0) {
        if ([NSURL URLWithString:trimmedURL] == nil) {
            AMALogError(@"Server returned invalid URL %@", url);
        }
        else {
            validatedURL = [trimmedURL copy];
        }
    }
    return validatedURL;
}

- (NSString *)trimmedString:(NSString *)str
{
    return [str stringByTrimmingCharactersInSet:[NSCharacterSet whitespaceAndNewlineCharacterSet]];
}

- (NSNumber *)serverTimeOffsetWithResponse:(NSHTTPURLResponse *)HTTPResponse
{
    NSNumber *offset = nil;
    NSString *date = HTTPResponse.allHeaderFields[@"Date"];
    if (date != nil) {
        NSDate *serverDate = [[self serverDateFormatter] dateFromString:date];
        if (serverDate != nil) {
            offset = @([serverDate timeIntervalSinceDate:[NSDate date]]);
        }
    }
    return offset;
}

- (NSDateFormatter *)serverDateFormatter
{
    static NSDateFormatter *serverDataFormatter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        serverDataFormatter = [[NSDateFormatter alloc] init];
        serverDataFormatter.locale = [[NSLocale alloc] initWithLocaleIdentifier:@"en_US"];
        serverDataFormatter.timeZone = [NSTimeZone timeZoneWithAbbreviation:@"GMT"];
        serverDataFormatter.dateFormat = @"EEE',' dd MMM yyyy HH':'mm':'ss z";
    });
    return serverDataFormatter;
}

- (NSArray *)permissionsListForArray:(NSArray *)array
{
    return [AMACollectionUtilities mapArray:array withBlock:^id(id item) {
        if ([item[kAMAStartupResponseEnabledKey] boolValue]) {
            return item[@"name"];
        }
        return nil;
    }];
}

- (NSArray<AMAPair *> *)deeplinkConditionsForArray:(NSArray *)array
{
    NSMutableArray<AMAPair *> *conditions = [[NSMutableArray alloc] init];
    if (array != nil) {
        for (NSDictionary *parsedCondition in array)  {
            NSString *key = parsedCondition[@"key"];
            if (key.length > 0) {
                [conditions addObject:[[AMAPair alloc] initWithKey:key value:parsedCondition[@"value"]]];
            }
        }
    }
    return [conditions copy];
}
@end
