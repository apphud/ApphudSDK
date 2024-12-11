
#import "AMADispatchStrategy.h"

@protocol AMACancelableExecuting;

NS_ASSUME_NONNULL_BEGIN

@interface AMATimerDispatchStrategy : AMADispatchStrategy

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithDelegate:(id<AMADispatchStrategyDelegate>)delegate
                         storage:(AMAReporterStorage *)storage
                        executor:(nullable id<AMACancelableExecuting>)executor
       executionConditionChecker:(id<AMAReportExecutionConditionChecker>)executionConditionCheckerNS_DESIGNATED_INITIALIZER;

@end

NS_ASSUME_NONNULL_END
