
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMAPlatformCurrentState.h"

@implementation AMAPlatformLocaleState

#pragma mark - Public

+ (NSString *)fullLocaleIdentifier
{
    NSString *language = [[[AMAPlatformCurrentState currentLanguage] componentsSeparatedByString:@"-"] firstObject];
    NSString *scriptCode = [self scriptCode];
    NSString *countryCode = [AMAPlatformCurrentState countryCode];

    NSMutableString *localeIdentifier = [language mutableCopy];

    if (scriptCode != nil) {
        [localeIdentifier appendFormat:@"-%@", scriptCode];
    }

    if (countryCode != nil) {
        [localeIdentifier appendFormat:@"_%@", countryCode];
    }
    
    return [localeIdentifier copy];
}

#pragma mark - Private

+ (NSString *)scriptCode
{
    NSLocale *locale = [NSLocale currentLocale];
    NSString *scriptCode = [locale objectForKey:NSLocaleScriptCode];

    return scriptCode;
}

@end
