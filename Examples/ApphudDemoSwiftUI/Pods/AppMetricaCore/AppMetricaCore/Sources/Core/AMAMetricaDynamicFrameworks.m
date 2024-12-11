
#import "AMAMetricaDynamicFrameworks.h"

static NSString *gAMASFrameworkBasePath = nil;

@implementation AMAMetricaDynamicFrameworks

#pragma mark - Public -

+ (AMAFramework *)sServices
{
    return [self frameworkWithName:@"SafariServices.framework"];
}

+ (AMAFramework *)adServices
{
    return [self frameworkWithName:@"AdServices.framework"];
}

+ (AMAFramework *)sConfiguration
{
    return [self frameworkWithName:@"SystemConfiguration.framework"];
}

+ (AMAFramework *)storeKit
{
    return [self frameworkWithName:@"StoreKit.framework"];
}

#pragma mark - Private -

+ (AMAFramework *)frameworkWithName:(NSString *)name
{
    NSString *path = [self pathForSFrameworkAtRelativePath:name];
    return [[AMAFramework alloc] initWithBundleAtPath:path];
}

+ (NSString *)pathForSFrameworkAtRelativePath:(NSString *)relativePath
{
    return [self pathForSFrameworkWithBasePath:self.frameworkPath relativePath:relativePath];
}

+ (NSString *)pathForSFrameworkWithBasePath:(NSString *)basePath relativePath:(NSString *)relativePath
{
    if (relativePath == nil || basePath == nil) {
        return nil;
    }
    return [basePath stringByAppendingPathComponent:relativePath];
}

+ (void)setSFrameworkBasePath:(NSString *)path
{
    // For autotests only!
    // This method is used by autotests agent to change framework paths for running on simulators.
    gAMASFrameworkBasePath = path;
}

+ (NSString *)frameworkPath
{
    if (gAMASFrameworkBasePath != nil) {
        return gAMASFrameworkBasePath;
    }
    NSString *basePath = [[[NSProcessInfo processInfo] environment] objectForKey:@"DYLD_ROOT_PATH"] ?: @"";
    return [basePath stringByAppendingPathComponent:@"/System/Library/Frameworks/"];
}

@end
