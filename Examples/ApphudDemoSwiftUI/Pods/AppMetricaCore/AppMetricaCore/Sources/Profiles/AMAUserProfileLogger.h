
#import <Foundation/Foundation.h>

@interface AMAUserProfileLogger : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (void)logAttributeNameTooLong:(NSString *)name;
+ (void)logTooManyCustomAttributesWithAttributeName:(NSString *)name;
+ (void)logForbiddenAttributeNamePrefixWithName:(NSString *)name forbiddenPrefix:(NSString *)forbiddenPrefix;
+ (void)logStringAttributeValueTruncation:(NSString *)value attributeName:(NSString *)name;

+ (void)logInvalidDateWithAttributeName:(NSString *)name;
+ (void)logInvalidGenderTypeWithAttributeName:(NSString *)name;

+ (void)logProfileIDTooLong:(NSString *)profileID;

@end
