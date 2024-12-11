
#import "AMACore.h"
#import "AMAPermissionsSerializer.h"
#import "AMAPermission.h"

@implementation AMAPermissionsSerializer

#pragma mark - Public -

+ (NSString *)JSONStringForPermissions:(NSArray<AMAPermission *> *)permissions
{
    NSMutableArray *serializedPermissions = [NSMutableArray arrayWithCapacity:permissions.count];
    for (AMAPermission *permission in permissions) {
        [serializedPermissions addObject:[self dictionaryForObject:permission]];
    }
    return [AMAJSONSerialization stringWithJSONObject:@{ @"permissions" : serializedPermissions } error:nil];
}

#pragma mark - Private -

+ (NSString *)stringForGrantType:(AMAPermissionGrantType)grantType
{
    switch (grantType) {
        case AMAPermissionGrantTypeAuthorized:
            return @"authorized";
        case AMAPermissionGrantTypeDenied:
            return @"denied";
        case AMAPermissionGrantTypeRestricted:
            return @"restricted";
        case AMAPermissionGrantTypeNotDetermined:
        default:
            return @"not_determined";
    }
}

+ (NSDictionary *)dictionaryForObject:(AMAPermission *)permission
{
    return @{
        @"name" : permission.name,
        @"granted" : @(permission.isGranted),
        @"grant_type" : [self stringForGrantType:permission.grantType],
    };
}

@end
