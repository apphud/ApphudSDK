
#import "AMAAttributeKey.h"

@implementation AMAAttributeKey

- (instancetype)initWithName:(NSString *)name type:(AMAAttributeType)type
{
    self = [super init];
    if (self != nil) {
        _name = [name copy];
        _type = type;
    }
    return self;
}

- (NSUInteger)hash
{
    return [self.name hash] * 23 + (NSUInteger)self.type;
}

- (BOOL)isEqual:(AMAAttributeKey *)other
{
    if (other == self) {
        return YES;
    }
    BOOL isEqual = [other isKindOfClass:[self class]];
    isEqual = isEqual && (other.type == self.type);
    isEqual = isEqual && (other.name == self.name || [other.name isEqualToString:self.name]);
    return isEqual;
}

- (instancetype)copyWithZone:(nullable NSZone *)zone
{
    return self;
}

@end
