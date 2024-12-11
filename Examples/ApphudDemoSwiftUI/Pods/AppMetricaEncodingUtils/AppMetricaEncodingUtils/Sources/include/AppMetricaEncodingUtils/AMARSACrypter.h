
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

NS_ASSUME_NONNULL_BEGIN

@class AMARSAKey;

NS_SWIFT_NAME(RSACrypter)
@interface AMARSACrypter : NSObject <AMADataEncoding>

@property (nonatomic, strong, readonly) AMARSAKey *publicKey;
@property (nonatomic, strong, readonly) AMARSAKey *privateKey;

+ (NSString *)message;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithPublicKey:(AMARSAKey *)publicKey privateKey:(AMARSAKey *)privateKey;

@end

NS_ASSUME_NONNULL_END
