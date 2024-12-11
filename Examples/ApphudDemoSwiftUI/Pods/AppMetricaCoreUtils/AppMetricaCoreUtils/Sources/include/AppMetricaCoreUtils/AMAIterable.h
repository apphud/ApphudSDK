
#import <Foundation/Foundation.h>

NS_SWIFT_NAME(Iterable)
@protocol AMAIterable <NSObject>

- (id)current;
- (id)next;

@end

NS_SWIFT_NAME(ResettableIterable)
@protocol AMAResettableIterable <AMAIterable>

- (void)reset;

@end
