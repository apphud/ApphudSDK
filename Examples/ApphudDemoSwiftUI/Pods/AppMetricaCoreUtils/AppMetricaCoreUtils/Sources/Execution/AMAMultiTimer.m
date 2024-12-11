
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@interface AMAMultiTimer () {
    AMAMultiTimerStatus _status;
}

@property (nonatomic, nullable) id<AMAResettableIterable> iterator;
@property (nonatomic, readonly) id<AMACancelableExecuting> executor;

- (void)scheduleNextDelay;

@end

@implementation AMAMultiTimer

- (instancetype)initWithDelays:(NSArray<NSNumber *> *)delays
                      executor:(id<AMACancelableExecuting>)executor
                      delegate:(nullable id<AMAMultiTimerDelegate>)delegate
{
    self = [super init];
    if (self) {
        _executor = executor;
        _iterator = [[AMAArrayIterator alloc] initWithArray:delays];
        _delegate = delegate;
    }
    return self;
}

- (AMAMultiTimerStatus)status
{
    @synchronized (self) {
        return _status;
    }
}

- (void)start
{
    @synchronized (self) {
        if (_status == AMAMultitimerStatusStarted) {
            return;
        }
        [self.executor cancelDelayed];
        [self.iterator reset];
        [self scheduleNextDelay];
    }
}

- (void)invalidate
{
    @synchronized (self) {
        [self.executor cancelDelayed];
        [self.iterator reset];
        _status = AMAMultitimerStatusNotStarted;
    }
}

- (void)onTimerFired
{
    // self.status use @synchronized(self)
    if (self.status != AMAMultitimerStatusStarted) {
        return;
    }
    
    [self.delegate multitimerDidFire:self];
    @synchronized (self) {
        if (_status == AMAMultitimerStatusStarted) {
            [self scheduleNextDelay];
        }
    }
}

- (void)scheduleNextDelay
{
    NSNumber *interval = [self.iterator current];
    if (interval != nil) {
        _status = AMAMultitimerStatusStarted;
        __weak typeof(self) weakSelf = self;
        [self.iterator next];
        [self.executor executeAfterDelay:interval.doubleValue block:^{
            [weakSelf onTimerFired];
        }];
    }
    else {
        _status = AMAMultitimerStatusNotStarted;
    }
}


@end
