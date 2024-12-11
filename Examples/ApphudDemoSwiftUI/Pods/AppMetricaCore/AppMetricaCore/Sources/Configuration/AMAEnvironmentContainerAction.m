
#import "AMAEnvironmentContainerAction.h"
#import "AMACore.h"

@implementation AMAEnvironmentContainerAddValueAction

- (instancetype)initWithValue:(NSString *)value forKey:(NSString *)key
{
    self = [super init];
    if (self) {
        _value = [value copy];
        _key = [key copy];
    }
    return self;
}

- (void)applyToContainer:(AMAEnvironmentContainer *)container
{
    [container addValue:self.value forKey:self.key];
}

#if AMA_ALLOW_DESCRIPTIONS
- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", [super description]];
    [description appendFormat:@"self.key=%@", self.key];
    [description appendFormat:@", self.value=%@", self.value];
    [description appendString:@">"];
    return description;
}
#endif

@end

@implementation AMAEnvironmentContainerClearAction

- (void)applyToContainer:(AMAEnvironmentContainer *)container
{
    [container clearEnvironment];
}

@end
