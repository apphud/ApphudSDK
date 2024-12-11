
#import "AMAPlatformCurrentState.h"

static NSString *const kAMADefaultFormat = @"%@-%@";

@implementation AMAPlatformCurrentState

+ (NSString *)fullLocaleIdentifier
{
//    http://tools.ietf.org/html/rfc5646#section-2.1
    NSString *language = [self preferredLanguage];
    NSString *countryCode = [self countryCode];

    NSString *localeIdentifier = language;
    if ([[self class] hasCountryCode:countryCode inLanguage:language] == NO) {
        localeIdentifier = [NSString stringWithFormat:kAMADefaultFormat, language, countryCode];
    }
    return localeIdentifier;
}

+ (NSString *)fullLocaleIdentifierWithFormat:(NSString *)format
{
    NSString *language = [[self class] currentLanguage];
    NSString *countryCode = [[self class] countryCode];
    NSString *localeIdentifier = [NSString stringWithFormat:format, language, countryCode];
    return localeIdentifier;
}

+ (NSString *)countryCode
{
    NSLocale *locale = [NSLocale currentLocale];
    NSString *countryCode = [locale objectForKey:NSLocaleCountryCode];
    return countryCode;
}

+ (NSString *)currentLanguage
{
    NSString *language = [[self class] preferredLanguage];
    if (language != nil) {
        NSString *countryCode = [[self class] countryCode];
        if ([[self class] hasCountryCode:countryCode inLanguage:language]) {
            NSUInteger countryCodeIndex = language.length - countryCode.length - 1;
            language = [language substringToIndex:countryCodeIndex];
        }
    }
    return language;
}

+ (NSString *)preferredLanguage
{
    NSArray *preferredLanguages = [NSLocale preferredLanguages];
    return preferredLanguages.firstObject;
}

+ (BOOL)hasCountryCode:(NSString *)countryCode inLanguage:(NSString *)language
{
    NSString *suffix = [NSString stringWithFormat:kAMADefaultFormat, @"", countryCode];
    return [language hasSuffix:suffix];
}

+ (NSString *)localeIdentifier
{
    NSLocale *locale = [NSLocale currentLocale];
    return [locale localeIdentifier];
}

@end
