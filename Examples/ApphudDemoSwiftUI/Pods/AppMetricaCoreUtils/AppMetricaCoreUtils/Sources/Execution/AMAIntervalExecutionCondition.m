
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMACoreUtilsLogging.h"

@interface AMAIntervalExecutionCondition ()

@property (nonatomic, strong, readonly) NSDate *lastExecuted;
@property (nonatomic, assign, readonly) NSTimeInterval interval;
@property (nonatomic, strong, readonly) id<AMAExecutionCondition> underlyingCondition;
@property (nonatomic, strong, readonly) id<AMADateProviding> dateProvider;

@end

@implementation AMAIntervalExecutionCondition

- (instancetype)initWithLastExecuted:(NSDate *)lastExecuted
                            interval:(NSTimeInterval)interval
                 underlyingCondition:(id<AMAExecutionCondition>)underlyingCondition
                        dateProvider:(id<AMADateProviding>)dateProvider
{
    self = [super init];
    if (self != nil) {
        _lastExecuted = lastExecuted;
        _interval = interval;
        _underlyingCondition = underlyingCondition;
        _dateProvider = dateProvider;
    }
    return self;
}

- (instancetype)initWithLastExecuted:(NSDate *)lastExecuted
                            interval:(NSTimeInterval)interval
                 underlyingCondition:(id<AMAExecutionCondition>)underlyingCondition
{
    return [self initWithLastExecuted:lastExecuted
                             interval:interval
                  underlyingCondition:underlyingCondition
                         dateProvider:[[AMADateProvider alloc] init]];
}

- (BOOL)shouldExecute
{
    BOOL shouldExecute = YES;
    if (self.lastExecuted != nil && [self.lastExecuted isEqual:NSDate.distantPast] == NO) {
        NSTimeInterval timeSinceLastExecution = [self.dateProvider.currentDate timeIntervalSinceDate:self.lastExecuted];
        NSTimeInterval timeRemaining = self.interval - timeSinceLastExecution;
        if (timeRemaining > DBL_EPSILON) {
            shouldExecute = NO;
            AMALogInfo(@"Interval hasn't passed: %.0f seconds left", timeRemaining);
        }
        else {
            AMALogInfo(@"Interval has passed: %.0f seconds ago", timeRemaining);
        }
    }
    else {
        AMALogInfo(@"First execution");
    }
    return shouldExecute && (self.underlyingCondition == nil || [self.underlyingCondition shouldExecute]);
}

@end
