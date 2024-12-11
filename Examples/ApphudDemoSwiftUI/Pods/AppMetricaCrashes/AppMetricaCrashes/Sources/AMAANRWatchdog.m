
#import "AMACrashLogging.h"
#import "AMAKSCrash.h"
#import "AMAANRWatchdog.h"
#import <AppMetricaPlatform/AppMetricaPlatform.h>

@interface AMAANRWatchdog ()

@property (atomic, assign, getter = isOperating) BOOL operating;
@property (nonatomic, assign) NSTimeInterval ANRDuration;
@property (nonatomic, assign) NSTimeInterval checkPeriod;

@property (nonatomic, strong) NSCondition *condition;
@property (nonatomic, strong) id<AMAAsyncExecuting> watchingExecutor;
@property (nonatomic, strong) id<AMAAsyncExecuting> observedExecutor;
@property (nonatomic, assign) BOOL predicate;

@end

@implementation AMAANRWatchdog

# pragma mark - Lifecycle

- (instancetype)initWithWatchdogInterval:(NSTimeInterval)watchdogInterval pingInterval:(NSTimeInterval)pingInterval
{
    dispatch_queue_t watchingQueue = [AMAQueuesFactory serialQueueForIdentifierObject:self
                                                                               domain:[AMAPlatformDescription SDKBundleName]];
    AMAExecutor *watchingExecutor = [[AMAExecutor alloc] initWithQueue:watchingQueue];
    AMAExecutor *observedExecutor = [[AMAExecutor alloc] initWithQueue:dispatch_get_main_queue()];

    return [self initWithWatchdogInterval:watchdogInterval
                             pingInterval:pingInterval
                         watchingExecutor:watchingExecutor
                         observedExecutor:observedExecutor];
}

- (instancetype)initWithWatchdogInterval:(NSTimeInterval)watchdogInterval
                            pingInterval:(NSTimeInterval)pingInterval
                        watchingExecutor:(id<AMAAsyncExecuting>)watchingExecutor
                        observedExecutor:(id<AMAAsyncExecuting>)observedExecutor
{
    self = [super init];
    if (self != nil) {
        _condition = [[NSCondition alloc] init];
        _predicate = NO;
        _watchingExecutor = watchingExecutor;
        _observedExecutor = observedExecutor;
        
        _operating = NO;
        _ANRDuration = watchdogInterval;
        _checkPeriod = pingInterval;
    }
    return self;
}

- (void)dealloc
{
    _operating = NO;
    [_condition unlock];
}

# pragma mark - Public

- (void)start
{
    @synchronized (self) {
        if (self.operating == NO) {
            self.operating = YES;
            __weak typeof(self) weakSelf = self;
            [self.watchingExecutor execute:^{
                [weakSelf startMonitoring];
            }];
        }
    }
}

- (void)cancel
{
    self.operating = NO;
}

# pragma mark - Private

- (void)startMonitoring
{
    while (self.isOperating) {
        [self.condition lock];
        
        __weak typeof(self) weakSelf = self;
        [self.observedExecutor execute:^{
            if (weakSelf != nil) {
                [weakSelf.condition lock];
                weakSelf.predicate = YES;
                [weakSelf.condition signal];
                [weakSelf.condition unlock];
            }
        }];

        NSDate *untilDate = [NSDate dateWithTimeIntervalSinceNow:self.ANRDuration];
        while ([self.condition waitUntilDate:untilDate] && self.predicate == NO) {
            // Pass in case of spurious wakeups
        }

        if (self.predicate == NO) {
            if (self.isOperating) {
                [self notifyOfANR];
            }
            [self.condition wait]; // Wait forever not to report the same suspension twice
        }

        self.predicate = NO;
        [self.condition unlock];

        [NSThread sleepForTimeInterval:self.checkPeriod];
    }
}

- (void)notifyOfANR
{
    AMALogInfo(@"ANR was detected. Trying to notify the delegate.");
    if ([self.delegate respondsToSelector:@selector(ANRWatchdogDidDetectANR:)]) {
        [self.delegate ANRWatchdogDidDetectANR:self];
    }
}

@end
