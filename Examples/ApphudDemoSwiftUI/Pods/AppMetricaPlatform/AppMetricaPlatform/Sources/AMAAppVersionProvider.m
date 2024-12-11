
#import "AMAAppVersionProvider.h"

@interface AMAAppVersionProvider ()

@property (nonatomic, strong, readonly) NSBundle *bundle;

@end

@implementation AMAAppVersionProvider

- (instancetype)init
{
    return [self initWithBundle:[NSBundle mainBundle]];
}

- (instancetype)initWithBundle:(NSBundle *)bundle
{
    self = [super init];
    if (self != nil) {
        _bundle = bundle;
    }
    return self;
}

- (NSString *)appID
{
    return [self.bundle bundleIdentifier];
}

- (NSString *)appBuildNumber
{
    return [self.bundle objectForInfoDictionaryKey:@"CFBundleVersion"];
}

- (NSString *)appVersion
{
    return [self.bundle objectForInfoDictionaryKey:@"CFBundleShortVersionString"];
}

- (NSString *)appVersionName
{
    NSString *bundleShortVersion = [self appVersion];
    NSUInteger appVersion = (NSUInteger)[bundleShortVersion integerValue];
    NSUInteger majorAppRevision = appVersion / 100;
    NSUInteger minorAppRevision = appVersion % 100;

    NSString *result = [[NSString alloc] initWithFormat:@"%u.%02u",
                                                        (unsigned)majorAppRevision,
                                                        (unsigned)minorAppRevision];
    return result;
}

@end
