#import <Foundation/Foundation.h>

#import "AMAIterable.h"

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(ArrayIterator)
@interface AMAArrayIterator : NSObject <AMAResettableIterable>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithArray:(NSArray *)array;

@end

NS_ASSUME_NONNULL_END
