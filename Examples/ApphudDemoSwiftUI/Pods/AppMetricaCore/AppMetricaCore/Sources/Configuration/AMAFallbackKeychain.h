
#import <Foundation/Foundation.h>
#import "AMAKeychainStoring.h"

@class AMAKeychain;
@protocol AMAKeyValueStoring;

NS_ASSUME_NONNULL_BEGIN

@interface AMAFallbackKeychain : NSObject <AMAKeychainStoring>

+ (NSString *)wrappedKey:(NSString *)key;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStorage:(id<AMAKeyValueStoring>)storage
                   mainKeychain:(AMAKeychain *)mainKeychain
               fallbackKeychain:(nullable AMAKeychain *)fallbackKeychain NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
