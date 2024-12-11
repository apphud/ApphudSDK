
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

NS_ASSUME_NONNULL_BEGIN

@class AMARSAKey;

extern NSString *const kAMARSAAESCrypterErrorDomain;

NS_SWIFT_NAME(RSAAESCrypter)
@interface AMARSAAESCrypter : NSObject <AMADataEncoding>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithPublicKey:(AMARSAKey *)publicKey privateKey:(nullable AMARSAKey *)privateKey;

@end

NS_ASSUME_NONNULL_END
