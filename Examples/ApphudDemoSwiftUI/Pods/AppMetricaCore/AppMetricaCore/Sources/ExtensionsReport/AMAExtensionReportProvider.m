
#import "AMACore.h"
#import "AMAExtensionReportProvider.h"

@implementation AMAExtensionReportProvider

#pragma mark - Public -

- (NSDictionary *)report
{
    NSDictionary *ownTypeInfo = nil;
    NSString *appBundleId = nil;
    NSDictionary *extensions = nil;

    NSDictionary *ownBundleInfo = [[NSBundle mainBundle] infoDictionary];
    NSString *ownExtensionType = [self typeOfExtensionForInfoDictionary:ownBundleInfo];
    if (ownExtensionType != nil) {
        NSString *extensionsPath = [[[NSBundle mainBundle] bundlePath] stringByDeletingLastPathComponent];
        NSString *appBundlePath = [extensionsPath stringByDeletingLastPathComponent];

        ownTypeInfo = @{ @"extension": ownExtensionType };
        appBundleId = [[NSBundle bundleWithPath:appBundlePath] bundleIdentifier];
        extensions = [self extensionsAtPath:extensionsPath];
    }
    else {
        NSString *extensionsPath = [[[NSBundle mainBundle] bundlePath] stringByAppendingPathComponent:@"PlugIns"];

        ownTypeInfo = @{ @"app": @"" };
        appBundleId = [[NSBundle mainBundle] bundleIdentifier];
        extensions = [self extensionsAtPath:extensionsPath];
    }

    NSDictionary *result = @{
        @"own_type": ownTypeInfo,
        @"app_bundle_id": appBundleId ?: @"unknown",
        @"extensions": extensions,
    };
    return result;
}

#pragma mark - Private -

- (NSString *)typeOfExtensionForInfoDictionary:(NSDictionary *)bundleInfo
{
    NSString *extensionType = nil;
    NSDictionary *extensionInfo = bundleInfo[@"NSExtension"];
    if ([extensionInfo isKindOfClass:[NSDictionary class]]) {
        extensionType = extensionInfo[@"NSExtensionPointIdentifier"];
    }
    return extensionType;
}

- (NSDictionary *)extensionsAtPath:(NSString *)path
{
    NSError *error = nil;
    NSMutableDictionary *extensions = [NSMutableDictionary dictionary];
    NSArray *extensionFileNames = [[NSFileManager defaultManager] contentsOfDirectoryAtPath:path error:&error];
    if (error == nil) {
        for (NSString *extensionFileName in extensionFileNames) {
            NSString *extensionPath = [path stringByAppendingPathComponent:extensionFileName];
            NSBundle *extensionBundle = [NSBundle bundleWithPath:extensionPath];
            NSString *extensionType = [self typeOfExtensionForInfoDictionary:[extensionBundle infoDictionary]];
            if (extensionType != nil) {
                NSMutableArray *bundleIds = extensions[extensionType] ?: [NSMutableArray array];
                NSString *bundleID = [extensionBundle bundleIdentifier] ?: @"unknown";
                [bundleIds addObject:bundleID];
                extensions[extensionType] = bundleIds;
            }
        }
    }
    else {
        AMALogWarn(@"Failed to get content of extensions directory: %@", error);
    }
    return extensions;
}

@end
