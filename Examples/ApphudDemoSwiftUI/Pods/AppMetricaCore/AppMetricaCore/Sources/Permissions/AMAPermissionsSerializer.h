
#import <Foundation/Foundation.h>

@class AMAPermission;

@interface AMAPermissionsSerializer : NSObject

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)new NS_UNAVAILABLE;

+ (NSString *)JSONStringForPermissions:(NSArray<AMAPermission *> *)permissions;

@end
