
#import "AMADispatchStrategy.h"

@protocol AMADelayedExecuting;

NS_ASSUME_NONNULL_BEGIN

@interface AMAEventCountDispatchStrategy : AMADispatchStrategy

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithDelegate:(id<AMADispatchStrategyDelegate>)delegate
                         storage:(AMAReporterStorage *)storage
                        executor:(nullable id<AMADelayedExecuting>)executor
       executionConditionChecker:(id<AMAReportExecutionConditionChecker>)executionConditionChecker NS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
