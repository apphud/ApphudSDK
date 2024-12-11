
#import <Foundation/Foundation.h>

@interface AMAStartupPermissionSerializer : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSDictionary *)permissionsWithArray:(NSArray *)array;
+ (NSDictionary *)permissionsWithJSONString:(NSString *)JSONString;
+ (NSString *)JSONStringWithPermissions:(NSDictionary *)permissionsDict;

@end
