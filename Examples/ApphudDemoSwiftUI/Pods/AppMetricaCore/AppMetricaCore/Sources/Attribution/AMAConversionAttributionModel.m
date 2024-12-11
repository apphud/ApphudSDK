
#import "AMACore.h"
#import "AMAConversionAttributionModel.h"
#import "AMAAttributionModelConfiguration.h"
#import "AMAConversionAttributionModelConfiguration.h"
#import "AMAEventTypes.h"
#import "AMAAttributionMapping.h"
#import "AMAEventCountByKeyHelper.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAClientEventCondition.h"
#import "AMAECommerceEventCondition.h"
#import "AMARevenueEventCondition.h"
#import "AMAEventFilter.h"
#import "AMALightECommerceEvent.h"
#import "AMALightRevenueEvent.h"

@interface AMAConversionAttributionModel()

@property (nonatomic, strong, readonly) AMAConversionAttributionModelConfiguration *config;
@property (nonatomic, strong, readonly) AMAEventCountByKeyHelper *eventCountByKeyHelper;

@end

@implementation AMAConversionAttributionModel

- (instancetype)initWithConfig:(AMAConversionAttributionModelConfiguration *)config
{
    return [self initWithConfig:config
          eventCountByKeyHelper:[[AMAEventCountByKeyHelper alloc] init]];
}

- (instancetype)initWithConfig:(AMAConversionAttributionModelConfiguration *)config
         eventCountByKeyHelper:(AMAEventCountByKeyHelper *)eventCountByKeyHelper
{
    self = [super init];
    if (self != nil) {
        _config = config;
        _eventCountByKeyHelper = eventCountByKeyHelper;
    }
    return self;
}

- (NSNumber *)checkAttributionForClientEvent:(NSString *)name
{
    return [self checkAttributionForEventWithType:AMAEventTypeClient
                                 conditionChecker:^BOOL (AMAEventFilter *filter) {
        return [filter.clientEventCondition checkEvent:name];
    }];
}

- (NSNumber *)checkAttributionForECommerceEvent:(AMALightECommerceEvent *)event
{
    if (event.isFirst == NO) {
        return nil;
    }
    return [self checkAttributionForEventWithType:AMAEventTypeECommerce
                                 conditionChecker:^BOOL (AMAEventFilter *filter) {
        return [filter.eCommerceEventCondition checkEvent:event.type];
    }];
}

- (NSNumber *)checkAttributionForRevenueEvent:(AMALightRevenueEvent *)event
{
    return [self checkAttributionForEventWithType:AMAEventTypeRevenue
                                 conditionChecker:^BOOL (AMAEventFilter *filter) {
        return [filter.revenueEventCondition checkEvent:event.isAuto];
    }];
}

- (NSNumber *)checkInitialAttribution
{
    NSNumber *result = nil;
    for (AMAAttributionMapping *mapping in self.config.mappings) {
        if (mapping.requiredCount == 0) {
            result = @(result.intValue | mapping.conversionValueDiff);
        }
    }
    return result;
}

- (NSNumber *)checkAttributionForEventWithType:(AMAEventType)type
                              conditionChecker:(BOOL (^)(AMAEventFilter *))conditionChecker
{
    NSInteger diff = 0;
    BOOL conversionValueUpdated = NO;
    AMALogInfo(@"Checking event of type %tu with config: %@", type, self.config);
    for (AMAAttributionMapping *mapping in self.config.mappings) {
        for (AMAEventFilter *filter in mapping.eventFilters) {
            NSString *key = [NSString stringWithFormat:@"%ld", (long) mapping.conversionValueDiff];
            if (filter.type == type && conditionChecker(filter)) {
                NSUInteger oldCount = [self.eventCountByKeyHelper getCountForKey:key];
                NSUInteger newCount = oldCount + 1;
                if (newCount <= mapping.requiredCount) {
                    [self.eventCountByKeyHelper setCount:newCount forKey:key];
                }
                if (newCount == mapping.requiredCount) {
                    diff = diff | mapping.conversionValueDiff;
                    AMALogInfo(@"Change conversion value by %ld. Result is %ld", (long) mapping.conversionValueDiff, (long) diff);
                    conversionValueUpdated = YES;
                }
                break;
            }
        }
    }
    if (conversionValueUpdated) {
        return  @([AMAMetricaConfiguration sharedInstance].persistent.conversionValue.integerValue | diff);
    } else {
        return nil;
    }
}

@end
