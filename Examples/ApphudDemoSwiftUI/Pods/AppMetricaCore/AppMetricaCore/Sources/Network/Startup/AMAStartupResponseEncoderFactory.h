
#import <Foundation/Foundation.h>

@protocol AMADataEncoding;

@interface AMAStartupResponseEncoderFactory : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (id<AMADataEncoding>)encoder;

@end
