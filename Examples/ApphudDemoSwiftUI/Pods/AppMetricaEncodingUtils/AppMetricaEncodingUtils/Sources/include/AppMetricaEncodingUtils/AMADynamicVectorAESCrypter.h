
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

NS_SWIFT_NAME(DynamicVectorAESCrypter)
@interface AMADynamicVectorAESCrypter : NSObject <AMADataEncoding>

@property (nonatomic, strong, readonly) NSData *key;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithKey:(NSData *)key;

@end
