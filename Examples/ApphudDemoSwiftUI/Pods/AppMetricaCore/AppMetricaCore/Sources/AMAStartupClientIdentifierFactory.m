
#import "AMAStartupClientIdentifierFactory.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAUUIDProvider.h"
#import "AMAStartupClientIdentifier.h"
#import <UIKit/UIKit.h>

@implementation AMAStartupClientIdentifierFactory

+ (AMAStartupClientIdentifier *)startupClientIdentifier
{
    AMAStartupClientIdentifier *identifier = [[AMAStartupClientIdentifier alloc] init];
    identifier.deviceID = [AMAMetricaConfiguration sharedInstance].persistent.deviceID;
    identifier.deviceIDHash = [AMAMetricaConfiguration sharedInstance].persistent.deviceIDHash;
    identifier.UUID = [AMAUUIDProvider sharedInstance].retrieveUUID;
    identifier.IFV = [[[UIDevice currentDevice] identifierForVendor] UUIDString];
    return identifier;
}

@end
