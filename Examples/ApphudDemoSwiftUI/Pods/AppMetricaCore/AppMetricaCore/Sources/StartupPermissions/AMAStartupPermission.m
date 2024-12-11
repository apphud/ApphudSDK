
#import "AMAStartupPermission.h"

@implementation AMAStartupPermission

- (instancetype)initWithName:(NSString *)name enabled:(BOOL)enabled
{
    self = [super init];
    if (self != nil) {
        _name = [name copy];
        _enabled = enabled;
    }
    return self;
}

- (BOOL)isEqual:(AMAStartupPermission *)startupPermission
{
    if ([startupPermission isKindOfClass:[AMAStartupPermission class]] == NO) {
        return NO;
    }
    BOOL result = YES;
    result = result && (self.name == startupPermission.name || [self.name isEqualToString:startupPermission.name]);
    result = result && self.enabled == startupPermission.enabled;
    return result;
}

@end
