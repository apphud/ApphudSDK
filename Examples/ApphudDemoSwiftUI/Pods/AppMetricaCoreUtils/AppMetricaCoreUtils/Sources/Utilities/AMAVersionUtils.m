
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@implementation AMAVersionUtils

+ (BOOL)isOSVersionMajorAtLeast:(NSInteger)major
{
    NSOperatingSystemVersion version = (NSOperatingSystemVersion){major, 0, 0};
    return [AMAVersionUtils isOSVersionAtLeast:version];
}

+ (BOOL)isOSVersionAtLeast:(NSOperatingSystemVersion)version
{
    return [[NSProcessInfo processInfo] isOperatingSystemAtLeastVersion:version];
}

@end
