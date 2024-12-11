
#import "AMARegister.h"

@implementation AMARegister

- (instancetype)initWithName:(NSString *)name value:(uint64_t)value
{
    self = [super init];
    if (self != nil) {
        _name = [name copy];
        _value = value;
    }

    return self;
}

- (BOOL)isEqual:(id)object
{
    BOOL isEqual = [object isKindOfClass:[self class]];
    if (isEqual) {
        AMARegister *otherRegister = object;
        isEqual = otherRegister.name == self.name || [otherRegister.name isEqual:self.name];
        isEqual = isEqual && otherRegister.value == self.value;
    }
    return isEqual;
}

@end
