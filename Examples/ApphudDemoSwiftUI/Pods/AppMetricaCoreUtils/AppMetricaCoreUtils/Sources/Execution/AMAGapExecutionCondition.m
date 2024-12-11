
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMACoreUtilsLogging.h"

@interface AMAGapExecutionCondition ()

@property (nonatomic, strong, readonly) NSDate *firstStartupUpdate;
@property (nonatomic, strong, readonly) NSDate *lastStartupUpdate;
@property (nonatomic, strong, readonly) NSNumber *lastServerTimeOffset;
@property (nonatomic, assign, readonly) NSTimeInterval gap;
@property (nonatomic, strong, readonly) id<AMAExecutionCondition> underlyingCondition;

@end

@implementation AMAGapExecutionCondition

- (instancetype)initWithFirstStartupUpdate:(NSDate *)firstStartupUpdate
                         lastStartupUpdate:(NSDate *)lastStartupUpdate
                      lastServerTimeOffset:(NSNumber *)lastServerTimeOffset
                                       gap:(NSTimeInterval)gap
                       underlyingCondition:(id<AMAExecutionCondition>)underlyingCondition
{
    self = [super init];
    if (self != nil) {
        _firstStartupUpdate = firstStartupUpdate;
        _lastStartupUpdate = lastStartupUpdate;
        _lastServerTimeOffset = lastServerTimeOffset;
        _gap = gap;
        _underlyingCondition = underlyingCondition;
    }

    return self;
}

- (BOOL)shouldExecute
{
    BOOL shouldExecute = YES;
    NSTimeInterval timeSinceFirstStartupUpdate = [AMATimeUtilities timeSinceFirstStartupUpdate:self.firstStartupUpdate
                                                                         lastStartupUpdateDate:self.lastStartupUpdate
                                                                          lastServerTimeOffset:self.lastServerTimeOffset];
    NSTimeInterval timeRemaining = self.gap - timeSinceFirstStartupUpdate;
    if (timeRemaining < DBL_EPSILON) {
        shouldExecute = NO;
        AMALogInfo(@"Gap has passed: %.0f seconds ago", timeRemaining);
    }
    else {
        AMALogInfo(@"Gap hasn't passed: %.0f seconds remain", timeRemaining);
    }
    return shouldExecute && (self.underlyingCondition == nil || [self.underlyingCondition shouldExecute]);
}

@end
