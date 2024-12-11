
#import <Foundation/Foundation.h>
#import "AMAPermissionKeys.h"

@class AMAPermission;

@interface AMAPermissionsExtractor : NSObject

- (NSArray<AMAPermission *> *)permissionsForKeys:(NSArray<AMAPermissionKey> *)keys;

@end
