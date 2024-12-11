
#import <Foundation/Foundation.h>
#import "AMAPermissionKeys.h"

@interface AMAPermissionsConfiguration : NSObject

@property (nonatomic, strong, class, readonly) NSArray<AMAPermissionKey> * allKeys;

@property (nonatomic, assign, readonly) BOOL collectingEnabled;
@property (nonatomic, assign, readonly) NSTimeInterval collectingInterval;
@property (nonatomic, strong, readonly) NSArray<AMAPermissionKey> *keys;
@property (nonatomic, strong) NSDate *lastUpdateDate;

@end
