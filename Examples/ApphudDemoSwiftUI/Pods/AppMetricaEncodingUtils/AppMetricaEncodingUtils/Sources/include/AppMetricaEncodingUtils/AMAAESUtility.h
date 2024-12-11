
#import <Foundation/Foundation.h>

NS_SWIFT_NAME(AESUtility)
@interface AMAAESUtility : NSObject

+ (NSData *)randomIv;
+ (NSData *)defaultIv;
+ (NSData *)randomKeyOfSize:(NSUInteger)size;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
