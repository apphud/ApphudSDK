
#import "AMACore.h"
#import "AMATimerDispatchStrategy.h"
#import "AMAReporterStorage.h"
#import "AMAMetricaConfiguration.h"

@interface AMATimerDispatchStrategy ()

@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, strong) id<AMACancelableExecuting> executor;

@end

@implementation AMATimerDispatchStrategy

- (instancetype)initWithDelegate:(id<AMADispatchStrategyDelegate>)delegate
                         storage:(AMAReporterStorage *)storage
       executionConditionChecker:(id<AMAReportExecutionConditionChecker>)executionConditionChecker
{
    return [self initWithDelegate:delegate storage:storage executor:nil executionConditionChecker:executionConditionChecker];
}

- (instancetype)initWithDelegate:(id<AMADispatchStrategyDelegate>)delegate
                         storage:(AMAReporterStorage *)storage
                        executor:(id<AMACancelableExecuting>)executor
       executionConditionChecker:(id<AMAReportExecutionConditionChecker>)executionConditionChecker
{
    self = [super initWithDelegate:delegate storage:storage executionConditionChecker:executionConditionChecker];
    if (self) {
        if (executor == nil) {
            executor = [[AMACancelableDelayedExecutor alloc] initWithIdentifier:self];
        }
        _executor = executor;
    }

    return self;
}

#pragma mark - Public -

- (void)start
{
    [self.executor execute:^{
        NSUInteger timeoutInterval = [self timeout];
        if (timeoutInterval == 0) {
            [self.executor cancelDelayed];
            self.isActive = NO;
            return;
        }
        if (self.isActive) {
            AMALogAssert(@"The timer has already been set!");
            return;
        }
        
        __weak typeof (self) weakSelf = self;
        self.isActive = YES;
        [self.executor executeAfterDelay:timeoutInterval block:^{
            [weakSelf triggerDispatch];
            [weakSelf restart];
        }];
    }];
}

- (void)shutdown
{
    [self.executor execute:^{
        [self.executor cancelDelayed];
        self.isActive = NO;
    }];
}

- (void)restart
{
    [self.executor execute:^{
        [self shutdown];
        [self start];
    }];
}

#pragma mark - Private -

- (NSUInteger)timeout
{
    AMAReporterConfiguration *configuration =
            [[AMAMetricaConfiguration sharedInstance] configurationForApiKey:self.storage.apiKey];
    return configuration.dispatchPeriod;
}

@end
