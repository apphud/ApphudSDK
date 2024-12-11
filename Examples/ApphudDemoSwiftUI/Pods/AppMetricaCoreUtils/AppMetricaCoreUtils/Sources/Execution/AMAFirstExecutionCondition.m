
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMACoreUtilsLogging.h"

@interface AMAFirstExecutionCondition ()

@property (nonatomic, strong, readonly) NSDate *firstStartupUpdate;
@property (nonatomic, strong, readonly) NSDate *lastStartupUpdate;
@property (nonatomic, strong, readonly) NSDate *lastExecuted;
@property (nonatomic, strong, readonly) NSNumber *lastServerTimeOffset;
@property (nonatomic, assign, readonly) NSTimeInterval delay;
@property (nonatomic, strong, readonly) id<AMAExecutionCondition> underlyingCondition;

@end

@implementation AMAFirstExecutionCondition

- (instancetype)initWithFirstStartupUpdate:(NSDate *)firstStartupUpdate
                         lastStartupUpdate:(NSDate *)lastStartupUpdate
                              lastExecuted:(NSDate *)lastExecuted
                      lastServerTimeOffset:(NSNumber *)lastServerTimeOffset
                                     delay:(NSTimeInterval)delay
                       underlyingCondition:(id<AMAExecutionCondition>)underlyingCondition
{
    self = [super init];
    if (self != nil) {
        _firstStartupUpdate = firstStartupUpdate;
        _lastStartupUpdate = lastStartupUpdate;
        _lastExecuted = lastExecuted;
        _lastServerTimeOffset = lastServerTimeOffset;
        _delay = delay;
        _underlyingCondition = underlyingCondition;
    }
    return self;
}

- (BOOL)shouldExecute
{
    BOOL shouldExecute = YES;
    if (self.lastExecuted == nil || [self.lastExecuted isEqual:NSDate.distantPast]) {
        NSTimeInterval timeSinceFirstStartupUpdate =
            [AMATimeUtilities timeSinceFirstStartupUpdate:self.firstStartupUpdate
                                    lastStartupUpdateDate:self.lastStartupUpdate
                                     lastServerTimeOffset:self.lastServerTimeOffset];
        NSTimeInterval timeRemaining = self.delay - timeSinceFirstStartupUpdate;
        if (timeRemaining > DBL_EPSILON) {
            shouldExecute = NO;
            AMALogInfo(@"First interval hasn't passed: %.0f seconds left", timeRemaining);
        }
        else {
            AMALogInfo(@"First interval has passed: %.0f seconds ago", timeRemaining);
        }
    }
    else {
        AMALogInfo(@"Not a first execution");
    }
    return shouldExecute && (self.underlyingCondition == nil || [self.underlyingCondition shouldExecute]);
}

@end
