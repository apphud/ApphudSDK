
#import "AMAEventFilter.h"
#import "AMARevenueEventCondition.h"
#import "AMAClientEventCondition.h"
#import "AMAECommerceEventCondition.h"

static NSString *const kAMAEventType = @"event.type";
static NSString *const kAMAClientEventCondition = @"client.condition";
static NSString *const kAMAECommerceEventCondition = @"ecommerce.condition";
static NSString *const kAMARevenueEventCondition = @"revenue.condition";

@implementation AMAEventFilter

- (instancetype)initWithJSON:(NSDictionary *)json
{
    NSNumber *eventTypeNumber = json[kAMAEventType];
    AMAEventType type = (AMAEventType) eventTypeNumber.intValue;
    return [self initWithEventType:type
              clientEventCondition:[[AMAClientEventCondition alloc] initWithJSON:json[kAMAClientEventCondition]]
           eCommerceEventCondition:[[AMAECommerceEventCondition alloc] initWithJSON:json[kAMAECommerceEventCondition]]
             revenueEventCondition:[[AMARevenueEventCondition alloc] initWithJSON:json[kAMARevenueEventCondition]]];
}

- (instancetype)initWithEventType:(AMAEventType)type
             clientEventCondition:(AMAClientEventCondition *)clientEventCondition
          eCommerceEventCondition:(AMAECommerceEventCondition *)eCommerceEventCondition
            revenueEventCondition:(AMARevenueEventCondition *)revenueEventCondition
{
    self = [super init];
    if (self != nil) {
        _type = type;
        _clientEventCondition = clientEventCondition;
        _eCommerceEventCondition = eCommerceEventCondition;
        _revenueEventCondition = revenueEventCondition;
    }
    return self;
}

- (NSDictionary *)JSON
{
    NSMutableDictionary *json = [[NSMutableDictionary alloc] init];
    json[kAMAEventType] = @((int)self.type);
    json[kAMAClientEventCondition] = [self.clientEventCondition JSON];
    json[kAMAECommerceEventCondition] = [self.eCommerceEventCondition JSON];
    json[kAMARevenueEventCondition] = [self.revenueEventCondition JSON];
    return [json copy];
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.type=%lu", (unsigned long)self.type];
    [description appendFormat:@", self.clientEventCondition=%@", self.clientEventCondition];
    [description appendFormat:@", self.eCommerceEventCondition=%@", self.eCommerceEventCondition];
    [description appendFormat:@", self.revenueEventCondition=%@", self.revenueEventCondition];
    [description appendString:@">"];
    return description;
}


@end
