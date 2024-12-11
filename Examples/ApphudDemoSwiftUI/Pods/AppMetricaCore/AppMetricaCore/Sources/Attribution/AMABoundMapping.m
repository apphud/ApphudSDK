
#import "AMABoundMapping.h"

static NSString *const kAMABound = @"bound";
static NSString *const kAMAValue = @"value";

@implementation AMABoundMapping

- (instancetype)initWithJSON:(NSDictionary *)json
{
    if (json == nil) {
        return nil;
    }
    return [self initWithBound:[NSDecimalNumber decimalNumberWithString:json[kAMABound]]
                         value:((NSNumber *) json[kAMAValue])];
}

- (instancetype)initWithBound:(NSDecimalNumber *)bound value:(NSNumber *)value
{
    self = [super init];
    if (self != nil) {
        _bound = bound;
        _value = value;
    }
    return self;
}

- (NSDictionary *)JSON
{
    return @{
        kAMABound : self.bound.stringValue,
        kAMAValue : self.value
    };
}

- (NSComparisonResult)compare:(AMABoundMapping *)other
{
    return [self.bound compare:other.bound];
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.bound=%@", self.bound];
    [description appendFormat:@", self.value=%@", self.value];
    [description appendString:@">"];
    return description;
}


@end
