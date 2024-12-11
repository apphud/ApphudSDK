
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>

NSString *const kAMAUserDefaultsStringKeyPreviousBundleVersion = @"previous.bundle_version";
NSString *const kAMAUserDefaultsStringKeyPreviousOSVersion = @"previous.os_version";
NSString *const kAMAUserDefaultsStringKeyAppWasTerminated = @"app.was.terminated";
NSString *const kAMAUserDefaultsStringKeyAppWasInBackground = @"app.was.in.background";

static NSString *const kAMAUserDefaultsKeyPrefix =  @"io.appmetrica.sdk.";

@implementation AMAUserDefaultsStorage

- (NSUserDefaults *)defaults
{
    return [NSUserDefaults standardUserDefaults];
}

- (NSString *)prefixedKey:(NSString *)key
{
    return [kAMAUserDefaultsKeyPrefix stringByAppendingString:key];
}

- (void)synchronize
{
    [[self defaults] synchronize];
}

#pragma mark - Getters

- (NSString *)stringForKey:(NSString *)key
{
    return [[self defaults] stringForKey:[self prefixedKey:key]];
}

- (BOOL)boolForKey:(NSString *)key
{
    return [[self defaults] boolForKey:[self prefixedKey:key]];
}

#pragma mark - Setters

- (void)setObject:(id)object forKey:(id)key
{
    [[self defaults] setObject:object forKey:[self prefixedKey:key]];
}

- (void)setBool:(BOOL)flag forKey:(id)key
{
    [[self defaults] setBool:flag forKey:[self prefixedKey:key]];
}

@end
