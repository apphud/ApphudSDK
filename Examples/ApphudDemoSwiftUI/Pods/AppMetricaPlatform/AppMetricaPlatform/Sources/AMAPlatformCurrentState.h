
#import <Foundation/Foundation.h>

@interface AMAPlatformCurrentState : NSObject

+ (NSString *)countryCode;
+ (NSString *)currentLanguage;

+ (NSString *)localeIdentifier;
+ (NSString *)fullLocaleIdentifier;
+ (NSString *)fullLocaleIdentifierWithFormat:(NSString *)format;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
