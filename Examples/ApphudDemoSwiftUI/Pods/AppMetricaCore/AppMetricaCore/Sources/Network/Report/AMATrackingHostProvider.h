
#import <Foundation/Foundation.h>
#import "AMACore.h"

NS_ASSUME_NONNULL_BEGIN

@interface AMATrackingHostProvider : NSObject <AMAResettableIterable>

- (void)reset;

@end

NS_ASSUME_NONNULL_END
