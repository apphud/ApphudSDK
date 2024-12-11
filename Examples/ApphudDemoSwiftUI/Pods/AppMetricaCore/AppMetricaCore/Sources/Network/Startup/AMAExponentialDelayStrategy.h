
#import "AMADelayStrategy.h"

@interface AMAExponentialDelayStrategy : NSObject<AMADelayStrategy>

- (instancetype)initWithSlotDelayInterval:(NSTimeInterval)slotDelayInterval
                            maxRetryCount:(NSInteger)maxRetryCount;

@end
