#import <Foundation/Foundation.h>

#import "AMATruncating.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(LengthStringTruncator)
@interface AMALengthStringTruncator : NSObject <AMAStringTruncating>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithMaxLength:(NSUInteger)maxLength;

@end

NS_ASSUME_NONNULL_END
