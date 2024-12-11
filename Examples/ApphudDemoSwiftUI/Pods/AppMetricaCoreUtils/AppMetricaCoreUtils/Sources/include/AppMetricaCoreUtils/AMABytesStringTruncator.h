#import <Foundation/Foundation.h>

#import "AMATruncating.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(BytesStringTruncator)
@interface AMABytesStringTruncator : NSObject <AMAStringTruncating>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithMaxBytesLength:(NSUInteger)maxBytesLength;

@end

NS_ASSUME_NONNULL_END
