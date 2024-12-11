#import "AMACore.h"

#import "AMAAttributionModelParser.h"

#import "AMAAppMetrica+Internal.h"
#import "AMAAttributionConvertingUtils.h"
#import "AMAAttributionMapping.h"
#import "AMAAttributionModelConfiguration.h"
#import "AMABoundMapping.h"
#import "AMAClientEventCondition.h"
#import "AMAConversionAttributionModelConfiguration.h"
#import "AMACurrencyMapping.h"
#import "AMAECommerceEventCondition.h"
#import "AMAEngagementAttributionModelConfiguration.h"
#import "AMAEventFilter.h"
#import "AMAInternalEventsReporter.h"
#import "AMARevenueAttributionModelConfiguration.h"
#import "AMARevenueEventCondition.h"

static NSString *const kAMAKeySendingStopTimeSeconds = @"sending_stop_time_seconds";
static NSString *const kAMAKeyModelType = @"model_type";
static NSString *const kAMAKeyConversionModel = @"conversion_model";
static NSString *const kAMAKeyRevenueModel = @"revenue_model";
static NSString *const kAMAKeyEngagementModel = @"engagement_model";
static NSString *const kAMAKeyMaxSavedRevenueIDs = @"max_saved_revenue_ids";
static NSString *const kAMAKeyMapping = @"mapping";
static NSString *const kAMAKeyConversionValue = @"conversion_value";
static NSString *const kAMAKeyRequiredCount = @"required_count";
static NSString *const kAMAKeyEvents = @"events";
static NSString *const kAMAKeyEventType = @"event_type";
static NSString *const kAMAKeyClientEventsConditions = @"client_events_conditions";
static NSString *const kAMAKeyEventName = @"event_name";
static NSString *const kAMAKeyEComEventsConditions = @"ecom_events_conditions";
static NSString *const kAMAKeyRevenueEventsConditions = @"revenue_events_conditions";
static NSString *const kAMAKeyEComType = @"ecom_type";
static NSString *const kAMAKeySource = @"source";
static NSString *const kAMAKeyBound = @"bound";
static NSString *const kAMAKeyValue = @"value";
static NSString *const kAMAKeyCurrencyRate = @"currency_rate";
static NSString *const kAMAKeyCode = @"code";
static NSString *const kAMAKeyAmount = @"amount";
static NSString *const kAMAKeyError = @"error";
static NSString *const kAMAKeyModel = @"model";
static NSString *const kAMAKeyJSON = @"json";

@interface AMAAttributionModelParser ()

@property (nonatomic, strong, readonly) AMAInternalEventsReporter *reporter;

@end

@implementation AMAAttributionModelParser

- (instancetype)init
{
    return [self initWithReporter:[AMAAppMetrica sharedInternalEventsReporter]];
}

- (instancetype)initWithReporter:(AMAInternalEventsReporter *)reporter
{
    self = [super init];
    if (self != nil) {
        _reporter = reporter;
    }
    return self;
}

#pragma mark - Public -

- (AMAAttributionModelConfiguration *)parse:(NSDictionary *)json
{
    NSNumber *stopSendingTimeSeconds = json[kAMAKeySendingStopTimeSeconds];
    if (stopSendingTimeSeconds == nil) {
        [self reportError:@{ kAMAKeyError : @"No stopSendingTimeSeconds" }];
        return nil;
    }
    NSString *modelString = json[kAMAKeyModelType];
    AMAAttributionModelType type = [AMAAttributionConvertingUtils modelTypeForString:modelString];

    AMAConversionAttributionModelConfiguration *conversion;
    AMARevenueAttributionModelConfiguration *revenue;
    AMAEngagementAttributionModelConfiguration *engagement;

    switch (type) {
        case AMAAttributionModelTypeConversion: {
            conversion = [self parseConversion:json[kAMAKeyConversionModel]];
            if (conversion == nil) {
                return nil;
            }
            break;
        }
        case AMAAttributionModelTypeRevenue: {
            revenue = [self parseRevenue:json[kAMAKeyRevenueModel]];
            if (revenue == nil) {
                return nil;
            }
            break;
        }
        case AMAAttributionModelTypeEngagement: {
            engagement = [self parseEngagement:json[kAMAKeyEngagementModel]];
            if (engagement == nil) {
                return nil;
            }
            break;
        }
        case AMAAttributionModelTypeUnknown: {
            [self reportError:@{
                kAMAKeyError : @"Unknown attribution model type",
                @"input" : modelString ?: @"nil"
            }];
            return nil;
        }
    }
    return [[AMAAttributionModelConfiguration alloc] initWithType:type
                                               maxSavedRevenueIDs:json[kAMAKeyMaxSavedRevenueIDs]
                                           stopSendingTimeSeconds:stopSendingTimeSeconds
                                                       conversion:conversion
                                                          revenue:revenue
                                                       engagement:engagement];
}

#pragma mark - Private -

- (AMAConversionAttributionModelConfiguration *)parseConversion:(NSDictionary *)json
{
    if (json == nil) {
        [self reportError:@{ kAMAKeyError : @"No conversion config" }];
        return nil;
    }
    NSMutableArray<AMAAttributionMapping *> *mappings = [[NSMutableArray alloc] init];
    NSArray *mappingArrayJSON = json[kAMAKeyMapping];
    NSMutableArray<NSDictionary *> *errors = [NSMutableArray array];
    if (mappingArrayJSON != nil) {
        for (NSDictionary *mappingJSON in mappingArrayJSON) {
            NSNumber *conversionValue = mappingJSON[kAMAKeyConversionValue];
            if (conversionValue == nil) {
                [errors addObject:@{
                    kAMAKeyError : @"No conversion value",
                    kAMAKeyModel : kAMAKeyConversionModel
                }];
                continue;
            }
            NSNumber *requiredCount = mappingJSON[kAMAKeyRequiredCount];
            if (requiredCount == nil) {
                [errors addObject:@{
                    kAMAKeyError : @"No required count",
                    kAMAKeyModel : kAMAKeyConversionModel
                }];
                continue;
            }
            NSArray<AMAEventFilter *> *events = [self parseEvents:mappingJSON[kAMAKeyEvents]
                                                    possibleTypes:@[ @(AMAEventTypeClient), @(AMAEventTypeRevenue), @(AMAEventTypeECommerce) ]
                                                           errors:errors];
            if (events.count == 0) {
                continue;
            }
            [mappings addObject:[[AMAAttributionMapping alloc] initWithEventFilters:events
                                                                      requiredCount:requiredCount.unsignedIntegerValue
                                                                conversionValueDiff:conversionValue.integerValue]];
        }
    }
    if (errors.count > 0) {
        [self reportError:@{ @"Conversion model errors" : [errors copy] }];
    }
    if (mappings.count > 0) {
        return [[AMAConversionAttributionModelConfiguration alloc] initWithMappings:mappings];
    }
    else {
        [self reportError:@{
            kAMAKeyError : @"No mapping",
            kAMAKeyModel : kAMAKeyConversionModel
        }];
        return nil;
    }
}

- (AMARevenueAttributionModelConfiguration *)parseRevenue:(NSDictionary *)json
{
    if (json == nil) {
        [self reportError:@{ kAMAKeyError : @"No revenue config" }];
        return nil;
    }
    NSMutableArray<NSDictionary *> *errors = [NSMutableArray array];
    NSArray<AMAEventFilter *> *events = [self parseEvents:json[kAMAKeyEvents]
                                            possibleTypes:@[ @(AMAEventTypeRevenue), @(AMAEventTypeECommerce) ]
                                                   errors:errors];
    if (errors.count > 0) {
        [self reportError:@{ @"Revenue model events errors" : [errors copy]}];
    }
    if (events.count == 0) {
        return nil;
    }
    NSArray<AMABoundMapping *> *mappings = [self parseBoundMappings:json[kAMAKeyMapping]
                                                 boundParser:^NSDecimalNumber * (NSDictionary *json) {
        return [AMADecimalUtils decimalNumberWithString:json[kAMAKeyBound] or:nil];}
                                                      errors:errors];
    if (errors.count > 0) {
        [self reportError:@{ @"Revenue model mappings errors" : [errors copy]}];
    }
    if (mappings.count == 0) {
        return nil;
    }
    AMACurrencyMapping *currencyMapping = [self parseCurrencyMapping:json[kAMAKeyCurrencyRate] errors:errors];
    if (errors.count > 0) {
        [self reportError:@{ @"Revenue model currency errors" : [errors copy]}];
    }
    if (currencyMapping == nil) {
        return nil;
    }
    return [[AMARevenueAttributionModelConfiguration alloc] initWithBoundMappings:mappings
                                                                           events:events
                                                                  currencyMapping:currencyMapping];
}

- (AMAEngagementAttributionModelConfiguration *)parseEngagement:(NSDictionary *)json
{
    if (json == nil) {
        [self reportError:@{ kAMAKeyError : @"No engagement config" }];
        return nil;
    }
    NSMutableArray<NSDictionary *> *errors = [NSMutableArray array];
    NSArray<AMABoundMapping *> *mappings = [self parseBoundMappings:json[kAMAKeyMapping]
                                                        boundParser:^NSDecimalNumber * (NSDictionary *boundJSON) {
        NSNumber *number = boundJSON[kAMAKeyBound];
        if (number == nil) {
            return nil;
        }
        return [NSDecimalNumber decimalNumberWithDecimal:number.decimalValue];
    }
                                                             errors:errors];
    if (errors.count > 0) {
        [self reportError:@{ @"Engagement model mappings errors" : [errors copy]}];
    }
    if (mappings.count == 0) {
        return nil;
    }
    NSArray<AMAEventFilter *> *events = [self parseEvents:json[kAMAKeyEvents]
                                            possibleTypes:@[ @(AMAEventTypeClient), @(AMAEventTypeECommerce), @(AMAEventTypeRevenue) ]
                                                   errors:errors];
    if (errors.count > 0) {
        [self reportError:@{ @"Engagement model events errors" : [errors copy]}];
    }
    if (events.count == 0) {
        return nil;
    }
    return [[AMAEngagementAttributionModelConfiguration alloc] initWithEventFilters:events
                                                                      boundMappings:mappings];
}

- (NSArray<AMAEventFilter *> *)parseEvents:(NSArray *)eventsJSON
                             possibleTypes:(NSArray<NSNumber *> *)possibleTypes
                                    errors:(NSMutableArray<NSDictionary *> *)errors
{
    if (eventsJSON.count == 0) {
        [errors addObject:@{ kAMAKeyError : @"No event filters" }];
        return nil;
    }
    else {
        NSMutableArray<AMAEventFilter *> *events = [[NSMutableArray alloc] init];
        for (NSDictionary *eventJSON in eventsJSON) {
            NSError *error = nil;
            NSString *typeString = eventJSON[kAMAKeyEventType];
            AMAEventType eventType = [AMAAttributionConvertingUtils eventTypeForString:typeString
                                                                                 error:&error];
            if (error != nil || [possibleTypes containsObject:@(eventType)] == NO) {
                [errors addObject:@{
                    kAMAKeyError : @"Unknown event type",
                    kAMAKeyValue : typeString ?: @"nil"
                }];
                continue;
            }

            AMAClientEventCondition *clientEventCondition = nil;
            if (eventType == AMAEventTypeClient) {
                clientEventCondition = [self parseClientEventCondition:eventJSON[kAMAKeyClientEventsConditions] errors:errors];
                if (clientEventCondition == nil) {
                    continue;
                }
            }

            AMAECommerceEventCondition *eCommerceEventCondition= nil;
            if (eventType == AMAEventTypeECommerce) {
                eCommerceEventCondition = [self parseECommerceCondition:eventJSON[kAMAKeyEComEventsConditions] errors:errors];
                if (eCommerceEventCondition == nil) {
                    continue;
                }
            }
            NSDictionary *revenueEventConditions = eventJSON[kAMAKeyRevenueEventsConditions];
            AMARevenueEventCondition *revenueEventCondition = nil;
            if (eventType == AMAEventTypeRevenue) {
                revenueEventCondition = [self parseRevenueCondition:revenueEventConditions errors:errors];
                if (revenueEventCondition == nil) {
                    continue;
                }
            }
            [events addObject:[[AMAEventFilter alloc] initWithEventType:eventType
                                                   clientEventCondition:clientEventCondition
                                                eCommerceEventCondition:eCommerceEventCondition
                                                  revenueEventCondition:revenueEventCondition]];
        }
        return [events copy];
    }
}

- (NSArray<AMABoundMapping *> *)parseBoundMappings:(NSArray *)mappingsJSON
                                       boundParser:(NSDecimalNumber * (^)(NSDictionary *))boundParser
                                            errors:(NSMutableArray<NSDictionary *> *)errors
{
    if (mappingsJSON.count == 0) {
        [errors addObject:@{ kAMAKeyError : @"No mappings" }];
        return nil;
    }
    NSMutableArray<AMABoundMapping *> *mappings = [[NSMutableArray alloc] init];
    for (NSDictionary *mappingJSON in mappingsJSON) {
        NSDecimalNumber *bound = boundParser(mappingJSON);
        if (bound == nil) {
            [errors addObject:@{
                kAMAKeyError : @"No bound in mapping",
                kAMAKeyJSON : mappingJSON ?: @"nil"
            }];
            continue;
        }
        NSNumber *value = mappingJSON[kAMAKeyValue];
        if (value == nil) {
            [errors addObject:@{
                kAMAKeyError : @"No value in mapping",
                kAMAKeyJSON : mappingJSON ?: @"nil"
            }];
            continue;
        }
        [mappings addObject:[[AMABoundMapping alloc] initWithBound:bound value:value]];
    }
    [mappings sortUsingSelector:@selector(compare:)];
    return mappings;
}

- (AMACurrencyMapping *)parseCurrencyMapping:(NSArray *)currencyRateJSON errors:(NSMutableArray<NSDictionary *> *)errors
{
    if (currencyRateJSON.count == 0) {
        [errors addObject:@{ kAMAKeyError : @"No currency mapping" }];
        return nil;
    }
    NSMutableDictionary *mapping = [[NSMutableDictionary alloc] init];
    for (NSDictionary *item in currencyRateJSON) {
        NSString *code = item[kAMAKeyCode];
        if (code == nil) {
            [errors addObject:@{
                kAMAKeyError : @"No code in currency rate",
                kAMAKeyJSON : item ?: @"nil"
            }];
            continue;
        }
        NSDecimalNumber *amount = [AMADecimalUtils decimalNumberWithString:item[kAMAKeyAmount] or:nil];
        if (amount == nil) {
            [errors addObject:@{
                kAMAKeyError : @"Invalid amount in currency rate",
                kAMAKeyJSON : item ?: @"nil"
            }];
            continue;
        }
        mapping[code] = amount;
    }
    if (mapping.count == 0) {
        return nil;
    }
    return [[AMACurrencyMapping alloc] initWithMapping:mapping];
}

- (AMAECommerceEventCondition *)parseECommerceCondition:(NSDictionary *)json
                                                 errors:(NSMutableArray<NSDictionary *> *)errors
{
    if (json == nil) {
        [errors addObject:@{ kAMAKeyError : @"No e-commerce event conditions"}];
        return nil;
    }
    NSError *error = nil;
    NSString *typeString = json[kAMAKeyEComType];
    AMAECommerceEventType type = [AMAAttributionConvertingUtils eCommerceTypeForString:typeString error:&error];
    if (error != nil) {
        [errors addObject:@{
            kAMAKeyError : @"Unknown e-commerce event type",
            kAMAKeyValue : typeString ?: @"nil"
        }];
        return nil;
    }
    return [[AMAECommerceEventCondition alloc] initWithType:type];
}

- (AMAClientEventCondition *)parseClientEventCondition:(NSDictionary *)json
                                                errors:(NSMutableArray<NSDictionary *> *)errors
{
    if (json == nil) {
        [errors addObject:@{ kAMAKeyError: @"No client event conditions" }];
        return nil;
    }
    else {
        NSString *clientEventName = json[kAMAKeyEventName];
        if ([clientEventName length] == 0) {
            [errors addObject:@{
                kAMAKeyError : @"No client event name",
                kAMAKeyJSON : json
            }];
            return nil;
        }
        else {
            return [[AMAClientEventCondition alloc] initWithName:clientEventName];
        }
    }
}

- (AMARevenueEventCondition *)parseRevenueCondition:(NSDictionary *)json
                                             errors:(NSMutableArray<NSDictionary *> *)errors
{
    if (json == nil) {
        [errors addObject:@{ kAMAKeyError: @"No revenue event conditions" }];
        return nil;
    }
    NSError *error = nil;
    NSString *sourceString = json[kAMAKeySource];
    AMARevenueSource source = [AMAAttributionConvertingUtils revenueSourceForString:sourceString error:&error];
    if (error != nil) {
        [errors addObject:@{
            kAMAKeyError : @"Unknown revenue source",
            kAMAKeyValue : sourceString ?: @"nil"
        }];
        return nil;
    }
    return [[AMARevenueEventCondition alloc] initWithSource:source];
}

- (void)reportError:(NSDictionary *)parameters
{
    AMALogWarn(@"Could not parse attribution model. Error description: %@", parameters);
    [self.reporter reportSKADAttributionParsingError:parameters];
}

@end
