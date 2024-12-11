
#import "AMARevenueEventCondition.h"
#import "AMARevenueSource.h"

static NSString *const kAMAKeySource = @"source";

@interface AMARevenueEventCondition()

@property (nonatomic, assign, readonly) AMARevenueSource source;

@end

@implementation AMARevenueEventCondition

- (instancetype)initWithJSON:(NSDictionary *)json
{
    if (json == nil) {
        return nil;
    }
    AMARevenueSource source = (AMARevenueSource) ((NSNumber *)json[kAMAKeySource]).intValue;
    return [self initWithSource:source];
}

- (instancetype)initWithSource:(AMARevenueSource)source
{
    self = [super init];
    if (self != nil) {
        _source = source;
    }
    return self;
}

- (BOOL)checkEvent:(BOOL)isAuto
{
    switch (self.source) {
        case AMARevenueSourceAPI: return isAuto == NO;
        case AMARevenueSourceAuto: return isAuto;
        default: return NO;
    }
}

- (NSDictionary *)JSON
{
    return @{ kAMAKeySource : @((int)self.source) };
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.source=%lu", (unsigned long) self.source];
    [description appendString:@">"];
    return description;
}


@end
