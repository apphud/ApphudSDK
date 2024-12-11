
#import <Foundation/Foundation.h>

@class AMAUserProfileUpdate;

@interface AMAInvalidUserProfileUpdateFactory : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (AMAUserProfileUpdate *)invalidDateUpdateWithAttributeName:(NSString *)name;
+ (AMAUserProfileUpdate *)invalidGenderTypeUpdateWithAttributeName:(NSString *)name;

@end
