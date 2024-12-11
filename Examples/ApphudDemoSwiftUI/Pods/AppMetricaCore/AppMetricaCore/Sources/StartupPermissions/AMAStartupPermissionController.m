
#import "AMAStartupPermissionController.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAStartupParametersConfiguration.h"
#import "AMAStartupPermission.h"
#import "AMAStartupPermissionSerializer.h"

static NSString *const kAMALocationPermissionKey = @"NSLocationDescription";

@implementation AMAStartupPermissionController

- (BOOL)isLocationCollectingGranted
{
    AMAMetricaConfiguration *configuration = [AMAMetricaConfiguration sharedInstance];
    NSString *permissionsString = configuration.startup.permissionsString;
    NSDictionary *permissions = [AMAStartupPermissionSerializer permissionsWithJSONString:permissionsString];
    AMAStartupPermission *locationCollectingPermission = permissions[kAMALocationPermissionKey];
    return locationCollectingPermission.enabled && configuration.persistent.hadFirstStartup;
}

@end
