
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

NS_ASSUME_NONNULL_BEGIN

extern NSString *const kAMAAESDataEncoderErrorDomain;
extern NSUInteger const kAMAAESDataEncoderIVSize;
extern NSUInteger const kAMAAESDataEncoder128BitKeySize;

NS_SWIFT_NAME(AESCrypter)
@interface AMAAESCrypter : NSObject <AMADataEncoding>

@property (nonatomic, strong, readonly) NSData *key;
@property (nonatomic, strong, readonly) NSData *iv;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithKey:(NSData *)key iv:(NSData *)iv;

@end

NS_ASSUME_NONNULL_END
