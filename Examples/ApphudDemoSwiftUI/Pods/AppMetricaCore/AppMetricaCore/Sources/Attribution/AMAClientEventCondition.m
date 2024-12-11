
#import "AMAClientEventCondition.h"

@interface AMAClientEventCondition()

@property (nonatomic, copy, readonly) NSString *expectedName;

@end

static NSString *const kAMAKeyName = @"name";

@implementation AMAClientEventCondition

- (instancetype)initWithJSON:(NSDictionary *)json
{
    if (json == nil) {
        return nil;
    }
    return [self initWithName:json[kAMAKeyName]];
}

- (instancetype)initWithName:(NSString *)eventName
{
    self = [super init];
    if (self != nil) {
        _expectedName = [eventName copy];
    }
    return self;
}

- (BOOL)checkEvent:(NSString *)name
{
    return [self.expectedName isEqualToString:name];
}

- (NSDictionary *)JSON
{
    return @{ kAMAKeyName : self.expectedName };
}

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", NSStringFromClass([self class])];
    [description appendFormat:@"self.expectedName=%@", self.expectedName];
    [description appendString:@">"];
    return description;
}

@end
