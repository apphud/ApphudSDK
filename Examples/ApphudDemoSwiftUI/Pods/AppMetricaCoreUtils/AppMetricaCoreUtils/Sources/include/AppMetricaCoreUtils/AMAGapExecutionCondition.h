#import <Foundation/Foundation.h>

#import "AMAExecutionCondition.h"

NS_SWIFT_NAME(GapExecutionCondition)
@interface AMAGapExecutionCondition : NSObject <AMAExecutionCondition>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithFirstStartupUpdate:(NSDate *)firstStartupUpdate
                         lastStartupUpdate:(NSDate *)lastStartupUpdate
                      lastServerTimeOffset:(NSNumber *)lastServerTimeOffset
                                       gap:(NSTimeInterval)gap
                       underlyingCondition:(id<AMAExecutionCondition>)underlyingCondition;

@end
