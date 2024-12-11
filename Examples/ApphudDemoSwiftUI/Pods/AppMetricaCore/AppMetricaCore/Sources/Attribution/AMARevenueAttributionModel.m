
#import "AMACore.h"
#import "AMAEventSumBoundBasedModelHelper.h"
#import "AMARevenueAttributionModel.h"
#import "AMAAttributionModelConfiguration.h"
#import "AMARevenueAttributionModelConfiguration.h"
#import "AMACurrencyMapping.h"
#import "AMAEventFilter.h"
#import "AMARevenueEventCondition.h"
#import "AMAECommerceEventCondition.h"
#import "AMALightECommerceEvent.h"
#import "AMALightRevenueEvent.h"

@interface AMARevenueAttributionModel()

@property (nonatomic, strong, readonly) AMARevenueAttributionModelConfiguration *config;
@property (nonatomic, strong, readonly) AMAEventSumBoundBasedModelHelper *eventSumBoundBasedModelHelper;

@end

@implementation AMARevenueAttributionModel

- (instancetype)initWithConfig:(AMARevenueAttributionModelConfiguration *)config
{
    return [self initWithConfig:config
  eventSumBoundBasedModelHelper:[[AMAEventSumBoundBasedModelHelper alloc] init]];
}

- (instancetype)initWithConfig:(AMARevenueAttributionModelConfiguration *)config
 eventSumBoundBasedModelHelper:(AMAEventSumBoundBasedModelHelper *)eventSumBoundBasedModelHelper
{
    self = [super init];
    if (self != nil) {
        _config = config;
        _eventSumBoundBasedModelHelper  = eventSumBoundBasedModelHelper;
    }
    return self;
}

- (NSNumber *)checkInitialAttribution
{
    return [self.eventSumBoundBasedModelHelper calculateNewConversionValue:[NSDecimalNumber zero]
                                                             boundMappings:self.config.boundMappings];
}

- (NSNumber *)checkAttributionForClientEvent:(NSString *)name
{
    return nil;
}

- (NSNumber *)checkAttributionForRevenueEvent:(AMALightRevenueEvent *)event
{
    return [self checkAttribution:AMAEventTypeRevenue
                 conditionChecker:^BOOL (AMAEventFilter *filter) {
        return [filter.revenueEventCondition checkEvent:event.isAuto];
    }
                 additionProvider:^NSDecimalNumber *() {
        NSDecimalNumber *decimalQuantity = [[NSDecimalNumber alloc] initWithUnsignedInteger:event.quantity];
        NSDecimalNumber *rawAddition = [AMADecimalUtils decimalNumber:event.priceMicros
                                                bySafelyMultiplyingBy:decimalQuantity
                                                                   or:[NSDecimalNumber zero]];
        NSError *error = nil;
        NSDecimalNumber *result = [self.config.currencyMapping convert:rawAddition
                                                              currency:event.currency
                                                                 scale:1
                                                                 error:&error];
        if (error != nil) {
            AMALogWarn(@"Error: %@", error);
        }
        return result;
    }];
}

- (NSNumber *)checkAttributionForECommerceEvent:(AMALightECommerceEvent *)event
{
    return [self checkAttribution:AMAEventTypeECommerce
                 conditionChecker:^BOOL (AMAEventFilter *filter) {
                     return [filter.eCommerceEventCondition checkEvent:event.type];
                 }
                 additionProvider:^NSDecimalNumber *() {
        NSDecimalNumber *addition = [NSDecimalNumber zero];
        for (AMAECommerceAmount *amount in event.amounts) {
            NSError *error = nil;
            if (error != nil) {
                AMALogWarn(@"Error: %@", error);
            }
            NSDecimalNumber *converted = [self.config.currencyMapping convert:amount.value
                                                                     currency:amount.unit
                                                                        scale:1000000
                                                                        error:&error];
            addition = [AMADecimalUtils decimalNumber:addition
                                       bySafelyAdding:converted
                                                   or:addition];
        }
        return addition;
    }];
}

- (NSNumber *)checkAttribution:(AMAEventType)type
              conditionChecker:(BOOL (^)(AMAEventFilter *))conditionChecker
              additionProvider:(NSDecimalNumber * (^)(void))additionProvider
{
    for (AMAEventFilter *filter in self.config.events) {
        if (filter.type == type && conditionChecker(filter)) {
            NSDecimalNumber *addition = additionProvider();
            return [self.eventSumBoundBasedModelHelper calculateNewConversionValue:addition
                                                                     boundMappings:self.config.boundMappings];
        }
    }
    return nil;
}

@end
