
#import "AMAECommerceEventCondition.h"
#import "AMAAttributionKeys.h"

@interface AMAECommerceEventCondition()

@property (nonatomic, assign, readonly) AMAECommerceEventType expectedType;

@end

static NSString *const kAMAKeyType = @"type";

@implementation AMAECommerceEventCondition

- (instancetype)initWithJSON:(NSDictionary *)json
{
    if (json == nil) {
        return nil;
    }
    AMAECommerceEventType type = (AMAECommerceEventType) ((NSNumber *)json[kAMAKeyType]).intValue;
    return [self initWithType:type];
}

- (instancetype)initWithType:(AMAECommerceEventType)type
{
    self = [super init];
    if (self != nil) {
        _expectedType = type;
    }
    return self;
}


- (BOOL)checkEvent:(AMAECommerceEventType)type
{
    return self.expectedType == type;
}

- (NSDictionary *)JSON
{
    return @{ kAMAKeyType : @((int) self.expectedType) };
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.expectedType=%lu", (unsigned long)self.expectedType];
    [description appendString:@">"];
    return description;
}


@end
