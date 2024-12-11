
#import "AMACore.h"
#import "AMAStartupPermissionSerializer.h"
#import "AMAStartupPermission.h"

static NSString *const kAMAStartupPermissionNameIdentifier = @"name";
static NSString *const kAMAStartupPermissionEnabledIdentifier = @"enabled";

@implementation AMAStartupPermissionSerializer


#pragma mark - Public -

+ (NSDictionary *)permissionsWithArray:(NSArray *)array
{
    if (array == nil || [array isKindOfClass:[NSArray class]] == NO) {
        return nil;
    }
    NSMutableDictionary *permissions = [NSMutableDictionary dictionaryWithCapacity:array.count];
    for (NSDictionary *permissionDict in array) {
        if ([permissionDict isKindOfClass:[NSDictionary class]] == NO) {
            AMALogError(@"Permission should be a dictionary");
            continue;
        }
        AMAStartupPermission *permission = [self objectForDictionary:permissionDict];
        if (permission.name.length != 0) {
            permissions[permission.name] = permission;
        } else {
            AMALogInfo(@"Permission with nil name skipped");
        }
    }
    return [permissions copy];
}

+ (NSDictionary *)permissionsWithJSONString:(NSString *)JSONString
{
    NSArray *array = [AMAJSONSerialization arrayWithJSONString:JSONString error:nil];
    return [self permissionsWithArray:array];
}

+ (NSString *)JSONStringWithPermissions:(NSDictionary *)permissionsDictionary
{
    if (permissionsDictionary == nil) {
        return nil;
    }
    NSArray *permissions = [permissionsDictionary allValues];
    NSMutableArray *array = [NSMutableArray arrayWithCapacity:permissions.count];
    for (AMAStartupPermission *permission in permissions) {
        [array addObject:[self dictionaryForPermission:permission]];
    }
    return [AMAJSONSerialization stringWithJSONObject:array error:nil];
}

#pragma mark - Private -

+ (NSDictionary *)dictionaryForPermission:(AMAStartupPermission *)permission
{
    return @{
             kAMAStartupPermissionNameIdentifier : permission.name ?: @"",
             kAMAStartupPermissionEnabledIdentifier : @(permission.enabled)
             };
}

+ (AMAStartupPermission *)objectForDictionary:(NSDictionary *)dictionary
{
    return [[AMAStartupPermission alloc] initWithName:dictionary[kAMAStartupPermissionNameIdentifier]
                                              enabled:[dictionary[kAMAStartupPermissionEnabledIdentifier] boolValue]];
}

@end
