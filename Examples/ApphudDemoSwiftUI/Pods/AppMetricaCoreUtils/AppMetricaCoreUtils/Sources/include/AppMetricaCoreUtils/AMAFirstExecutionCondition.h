#import <Foundation/Foundation.h>

#import "AMAExecutionCondition.h"

NS_SWIFT_NAME(FirstExecutionCondition)
@interface AMAFirstExecutionCondition : NSObject <AMAExecutionCondition>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithFirstStartupUpdate:(NSDate *)firstStartupUpdate
                         lastStartupUpdate:(NSDate *)lastStartupUpdate
                              lastExecuted:(NSDate *)lastExecuted
                      lastServerTimeOffset:(NSNumber *)lastServerTimeOffset
                                     delay:(NSTimeInterval)delay
                       underlyingCondition:(id<AMAExecutionCondition>)underlyingCondition;

@end
