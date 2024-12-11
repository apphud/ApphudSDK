
#import "AMACore.h"
#import "AMADefaultStartupHostsProvider.h"
#import "AMAMetricaInMemoryConfiguration.h"
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

static NSString *const kAMADefaultStartupHostsKey = @"AMASDKStartupHosts";

@implementation AMADefaultStartupHostsProvider

#pragma mark - Public -

+ (NSArray *)startupHostsWithAdditionalHosts:(NSArray *)additionalStartupHosts
{
    NSArray *customStartupHosts = [[self class] filteredCustomStartupHosts:[[self class] customStartupHosts]];
    if (customStartupHosts.count > 0) {
        return customStartupHosts;
    }
    else {
        return [[[self class] predefinedStartupHosts] arrayByAddingObjectsFromArray:additionalStartupHosts];
    }
}

#pragma mark - Private -

+ (NSArray *)filteredCustomStartupHosts:(NSArray *)hosts
{
    NSArray *filteredHosts = [AMACollectionUtilities filteredArray:hosts withPredicate:^BOOL(id host) {
        return host != nil && [host isKindOfClass:[NSString class]] && ((NSString *)host).length > 0;
    }];
    return filteredHosts;
}

+ (NSArray *)customStartupHosts
{
    NSMutableArray *startupHosts = [NSMutableArray array];
    NSBundle *mainBundle = [NSBundle mainBundle];
    if ([[mainBundle.bundleURL pathExtension] isEqualToString:@"appex"]) {
        mainBundle = [NSBundle bundleWithURL:[[mainBundle.bundleURL URLByDeletingLastPathComponent] URLByDeletingLastPathComponent]];
    }
    else if ([[mainBundle.bundleURL pathExtension] isEqualToString:@"app"] == NO) {
        NSArray *loadedBundles = [AMACollectionUtilities filteredArray:[NSBundle allBundles] withPredicate:^BOOL(id bundle) {
            return ((NSBundle *)bundle).isLoaded;
        }];
        for (NSBundle* bundle in loadedBundles) {
            if (bundle.infoDictionary[kAMADefaultStartupHostsKey] != nil) {
                mainBundle = bundle;
            }
        }
    }
    if ([mainBundle.infoDictionary[kAMADefaultStartupHostsKey] isKindOfClass:[NSArray class]]) {
        startupHosts = mainBundle.infoDictionary[kAMADefaultStartupHostsKey] ?: startupHosts;
    }
    return startupHosts;
}

+ (NSArray *)predefinedStartupHosts
{
    return @[kAMADefaultStartupHost];
}

@end
