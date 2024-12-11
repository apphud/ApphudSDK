
#import "AMACrashLogging.h"
#import "AMAKSCrash.h"
#import "AMAKSCrashImports.h"
#import <objc/runtime.h>
#import <AppMetricaPlatform/AppMetricaPlatform.h>

static NSString *const kAMAAppMetricaCrashReportsDirectoryNamePostfix = @".CrashReports";

@implementation AMAKSCrash

+ (NSString *)crashesPath
{
    static NSString *path = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSArray *cachePaths = NSSearchPathForDirectoriesInDomains(NSCachesDirectory, NSUserDomainMask, YES);
        NSString *cachePath = [cachePaths firstObject];
        NSString *bundleName = [AMAPlatformDescription SDKBundleName];
        NSString *directoryName = [bundleName stringByAppendingString:kAMAAppMetricaCrashReportsDirectoryNamePostfix];
        path = [cachePath stringByAppendingPathComponent:directoryName];
    });
    return path;
}

@end
