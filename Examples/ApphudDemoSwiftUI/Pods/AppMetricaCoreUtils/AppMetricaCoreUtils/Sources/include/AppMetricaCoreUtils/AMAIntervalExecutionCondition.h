#import <Foundation/Foundation.h>

#import "AMAExecutionCondition.h"

@protocol AMADateProviding;

NS_SWIFT_NAME(IntervalExecutionCondition)
@interface AMAIntervalExecutionCondition : NSObject <AMAExecutionCondition>

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithLastExecuted:(NSDate *)lastExecuted
                            interval:(NSTimeInterval)interval
                 underlyingCondition:(id<AMAExecutionCondition>)underlyingCondition;

- (instancetype)initWithLastExecuted:(NSDate *)lastExecuted
                            interval:(NSTimeInterval)interval
                 underlyingCondition:(id<AMAExecutionCondition>)underlyingCondition
                        dateProvider:(id<AMADateProviding>)dateProvider;

@end
