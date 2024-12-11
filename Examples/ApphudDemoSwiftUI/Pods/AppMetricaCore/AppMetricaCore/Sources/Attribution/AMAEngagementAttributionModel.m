
#import "AMACore.h"
#import "AMAEngagementAttributionModel.h"
#import "AMAEventTypes.h"
#import "AMAEventCountByKeyHelper.h"
#import "AMAAttributionModelConfiguration.h"
#import "AMAAttributionMapping.h"
#import "AMAEngagementAttributionModelConfiguration.h"
#import "AMAECommerceEventCondition.h"
#import "AMAClientEventCondition.h"
#import "AMARevenueEventCondition.h"
#import "AMABoundMappingChecker.h"
#import "AMAEventFilter.h"
#import "AMALightECommerceEvent.h"
#import "AMALightRevenueEvent.h"

@interface AMAEngagementAttributionModel()

@property (nonatomic, strong, readonly) AMAEngagementAttributionModelConfiguration *config;
@property (nonatomic, strong, readonly) AMAEventCountByKeyHelper *eventCountByTypeAndNameHelper;
@property (nonatomic, strong, readonly) AMABoundMappingChecker *boundMappingChecker;

@end

static NSString *const key = @"engagement";

@implementation AMAEngagementAttributionModel

- (instancetype)initWithConfig:(AMAEngagementAttributionModelConfiguration *)config
{
    return [self initWithConfig:config
          eventCountByKeyHelper:[[AMAEventCountByKeyHelper alloc] init]
            boundMappingChecker:[[AMABoundMappingChecker alloc] init]];
}

- (instancetype)initWithConfig:(AMAEngagementAttributionModelConfiguration *)config
         eventCountByKeyHelper:(AMAEventCountByKeyHelper *)eventCountByKeyHelper
           boundMappingChecker:(AMABoundMappingChecker *)boundMappingChecker
{
    self = [super init];
    if (self != nil) {
        _config = config;
        _eventCountByTypeAndNameHelper = eventCountByKeyHelper;
        _boundMappingChecker = boundMappingChecker;
    }
    return self;
}

- (NSNumber *)checkAttributionForClientEvent:(NSString *)name
{
     return [self checkAttributionWithType:AMAEventTypeClient
                          conditionChecker:^BOOL (AMAEventFilter * filter) {
         return [filter.clientEventCondition checkEvent:name];
     }];
}

- (NSNumber *)checkAttributionForECommerceEvent:(AMALightECommerceEvent *)event
{
    if (event.isFirst == NO) {
        return nil;
    }
    return [self checkAttributionWithType:AMAEventTypeECommerce
                         conditionChecker:^BOOL (AMAEventFilter * filter) {
        return [filter.eCommerceEventCondition checkEvent:event.type];
    }];
}

- (NSNumber *)checkAttributionForRevenueEvent:(AMALightRevenueEvent *)event
{
    return [self checkAttributionWithType:AMAEventTypeRevenue
                         conditionChecker:^BOOL (AMAEventFilter * filter) {
        return [filter.revenueEventCondition checkEvent:event.isAuto];
    }];
}

- (NSNumber *)checkInitialAttribution
{
    return [self.boundMappingChecker check:[NSDecimalNumber zero] mappings:self.config.boundMappings];
}

#pragma mark Private -

- (NSNumber *)checkAttributionWithType:(AMAEventType)type
                      conditionChecker:(BOOL (^)(AMAEventFilter *))conditionChecker
{
    AMALogInfo(@"Checking event of type %lu with config %@", (unsigned long)type, self.config);
    NSNumber *result = nil;
    for (AMAEventFilter *eventFilter in self.config.eventFilters) {
        if (conditionChecker(eventFilter)) {
            NSUInteger newEventCount = [self.eventCountByTypeAndNameHelper getCountForKey:key] + 1;
            [self.eventCountByTypeAndNameHelper setCount:newEventCount forKey:key];
            result = [self.boundMappingChecker check:[[NSDecimalNumber alloc] initWithUnsignedInteger:newEventCount]
                                            mappings:self.config.boundMappings];
            AMALogInfo(@"For %lu result is %@", (unsigned long) newEventCount, result);
            break;
        }
    }
    return result;
}

@end
