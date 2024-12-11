
#import "AMACore.h"
#import <CoreLocation/CoreLocation.h>
#import "AMAPermissionsExtractor.h"
#import "AMAPermission.h"
#import "AMAAdProvider.h"

@interface AMAPermissionsExtractor ()

- (AMAPermissionGrantType)ATTStatus API_AVAILABLE(ios(14.0));

@end

@implementation AMAPermissionsExtractor

#pragma mark - Public -

- (NSArray<AMAPermission *> *)permissionsForKeys:(NSArray<AMAPermissionKey> *)keys;
{
    NSMutableArray *result = [NSMutableArray arrayWithCapacity:keys.count];
    AMALogInfo(@"Requesting permissions for: %@", keys);
    for (AMAPermissionKey key in keys) {
        AMAPermission *permission = self.permissionsBlocks[key]();
        if (permission != nil) {
            [result addObject:permission];
        }
    }
    AMALogInfo(@"Got permissions: %@", result);
    return [result copy];
}

#pragma mark - Private -

- (AMAPermission *)locationWhenInUsePermission
{
    return [AMAPermission permissionWithName:kAMAPermissionKeyLocationWhenInUse
                                   grantType:[self locationGrantTypeForPermission:kAMAPermissionKeyLocationWhenInUse]];
}

- (AMAPermission *)locationAlwaysPermission
{
    return [AMAPermission permissionWithName:kAMAPermissionKeyLocationAlways
                                   grantType:[self locationGrantTypeForPermission:kAMAPermissionKeyLocationAlways]];
}

- (AMAPermission *)ATTStatusPermission
{
    if (@available(iOS 14, tvOS 14, *)) {
        return [AMAPermission permissionWithName:kAMAPermissionKeyATTStatus
                                       grantType:[self ATTStatus]];
    }
    return nil;
}

- (AMAPermissionGrantType)locationGrantTypeForPermission:(AMAPermissionKey)permission
{
    switch ([CLLocationManager authorizationStatus]) {
        case kCLAuthorizationStatusNotDetermined:
            return AMAPermissionGrantTypeNotDetermined;
        case kCLAuthorizationStatusRestricted:
            return AMAPermissionGrantTypeRestricted;
        case kCLAuthorizationStatusDenied:
            return AMAPermissionGrantTypeDenied;
        case kCLAuthorizationStatusAuthorizedAlways:
            return AMAPermissionGrantTypeAuthorized;
        case kCLAuthorizationStatusAuthorizedWhenInUse: {
            if ([permission isEqualToString:kAMAPermissionKeyLocationAlways]) {
                return AMAPermissionGrantTypeDenied;
            }
            return AMAPermissionGrantTypeAuthorized;
        }
        default:
            return AMAPermissionGrantTypeNotDetermined;
    }
}

- (AMAPermissionGrantType)ATTStatus
{
    switch ([AMAAdProvider sharedInstance].ATTStatus) {
        case AMATrackingManagerAuthorizationStatusAuthorized:
            return AMAPermissionGrantTypeAuthorized;
        case AMATrackingManagerAuthorizationStatusDenied:
            return AMAPermissionGrantTypeDenied;
        case AMATrackingManagerAuthorizationStatusRestricted:
            return AMAPermissionGrantTypeRestricted;
        case AMATrackingManagerAuthorizationStatusNotDetermined:
        default:
            return AMAPermissionGrantTypeNotDetermined;
    }
}

- (NSDictionary<AMAPermissionKey, AMAPermission *(^)(void)> *)permissionsBlocks
{
    return @{
        kAMAPermissionKeyLocationWhenInUse : ^{ return [self locationWhenInUsePermission]; },
        kAMAPermissionKeyLocationAlways : ^{ return [self locationAlwaysPermission]; },
        kAMAPermissionKeyATTStatus : ^{ return [self ATTStatusPermission]; },
    };
}

@end
