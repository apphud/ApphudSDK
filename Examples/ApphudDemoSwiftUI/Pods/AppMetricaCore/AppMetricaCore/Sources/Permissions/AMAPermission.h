
#import <Foundation/Foundation.h>

typedef NS_ENUM(NSUInteger, AMAPermissionGrantType) {
    AMAPermissionGrantTypeNotDetermined = 0,
    AMAPermissionGrantTypeRestricted,
    AMAPermissionGrantTypeDenied,
    AMAPermissionGrantTypeAuthorized,
};

@interface AMAPermission : NSObject

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, assign, readonly) BOOL isGranted;
@property (nonatomic, assign, readonly) AMAPermissionGrantType grantType;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithName:(NSString *)name grantType:(AMAPermissionGrantType)grantType;

+ (instancetype)permissionWithName:(NSString *)name grantType:(AMAPermissionGrantType)grantType;

@end
