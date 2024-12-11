
#import <Foundation/Foundation.h>
#import "AMAKeychainStoring.h"

@class AMAKeychainBridge;

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kAMAKeychainErrorDomain;
extern NSString *const kAMAKeychainErrorKeyCode;

typedef NS_ENUM(NSInteger, kAMAKeychainErrorCode) {
    kAMAKeychainErrorCodeAdd = 0,
    kAMAKeychainErrorCodeUpdate = 1,
    kAMAKeychainErrorCodeGet = 2,
    kAMAKeychainErrorCodeRemove = 3,
    kAMAKeychainErrorCodeQueryCreation = 4,
    kAMAKeychainErrorCodeDecode = 5,
    kAMAKeychainErrorCodeInvalidType = 6, // Unused
};

@interface AMAKeychain : NSObject <AMAKeychainStoring>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (nullable instancetype)initWithService:(NSString *)service;
- (nullable instancetype)initWithService:(NSString *)service
                             accessGroup:(NSString *)accessGroup;
- (nullable instancetype)initWithService:(NSString *)service
                             accessGroup:(NSString *)accessGroup
                                  bridge:(AMAKeychainBridge *)bridge NS_DESIGNATED_INITIALIZER;

- (void)addStringValue:(NSString *)value forKey:(NSString *)key error:(NSError **)error;
- (void)removeStringValueForKey:(id)key error:(NSError **)error;

- (void)resetKeychain;

- (BOOL)isAvailable;

@end

NS_ASSUME_NONNULL_END
