
#import "AMAPermission.h"

@implementation AMAPermission

- (instancetype)initWithName:(NSString *)name grantType:(AMAPermissionGrantType)grantType
{
    self = [super init];
    if (self != nil) {
        _name = [name copy];
        _grantType = grantType;
    }
    return self;
}

+ (instancetype)permissionWithName:(NSString *)name grantType:(AMAPermissionGrantType)grantType
{
    return [[self.class alloc] initWithName:name grantType:grantType];
}

- (BOOL)isGranted
{
    return [self.class isGrantedForGrantType:self.grantType];
}

+ (BOOL)isGrantedForGrantType:(AMAPermissionGrantType)grantType
{
    switch (grantType) {
        case AMAPermissionGrantTypeAuthorized:
            return YES;
        case AMAPermissionGrantTypeNotDetermined:
        case AMAPermissionGrantTypeRestricted:
        case AMAPermissionGrantTypeDenied:
        default:
            return NO;
            
    }
}

#if AMA_ALLOW_DESCRIPTIONS

- (NSString *)description
{
    return [NSString stringWithFormat:@"<%@, name=%@, granted=%@, grantType=%lu>",
                [super description],
                self.name,
                self.isGranted ? @"YES" : @"NO",
                (unsigned long)self.grantType];
}

#endif

@end
