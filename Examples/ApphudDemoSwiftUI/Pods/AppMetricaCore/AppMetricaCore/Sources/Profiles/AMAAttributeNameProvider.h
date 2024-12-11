
#import <Foundation/Foundation.h>

extern NSString *const kAMAAttributeNameProviderPredefinedAttributePrefix;

@interface AMAAttributeNameProvider : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSString *)name;
+ (NSString *)gender;
+ (NSString *)birthDate;
+ (NSString *)notificationsEnabled;

+ (NSString *)customStringWithName:(NSString *)name;
+ (NSString *)customNumberWithName:(NSString *)name;
+ (NSString *)customCounterWithName:(NSString *)name;
+ (NSString *)customBoolWithName:(NSString *)name;

@end
