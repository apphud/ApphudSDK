
#import "AMAPrivacyTimer.h"
#import "AMAAdProvider.h"
#import "AMAPrivacyTimerStorage.h"
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@interface AMAPrivacyTimer () <AMAMultiTimerDelegate>

@property (nonnull, readonly) id<AMACancelableExecuting> executor;
@property (nonnull, readonly) AMAAdProvider *adProvider;

@property (nonnull, readonly) id<AMAAsyncExecuting> delegateExecutor;

@property (nonatomic, nullable, strong) AMAMultiTimer *timer;
@property (nonatomic) BOOL isStarted;

- (void)createTimer;
- (void)invalidateTimer;
- (void)fireEvent;
- (BOOL)isResendPeriodOutdated;

@end

@implementation AMAPrivacyTimer

- (instancetype)initWithTimerStorage:(id<AMAPrivacyTimerStorage>)timerStorage
                    delegateExecutor:(id<AMAAsyncExecuting>)delegateExecutor
                          adProvider:(AMAAdProvider*)adProvider
{
    AMACancelableDelayedExecutor *executor = [[AMACancelableDelayedExecutor alloc] initWithIdentifier:self];
    return [self initWithTimerStorage:timerStorage
                             executor:executor
                     delegateExecutor:delegateExecutor
                           adProvider:adProvider];
}

- (instancetype)initWithTimerStorage:(id<AMAPrivacyTimerStorage>)timerStorage
                            executor:(id<AMACancelableExecuting>)executor
                    delegateExecutor:(id<AMAAsyncExecuting>)delegateExecutor
                          adProvider:(AMAAdProvider *)adProvider
{
    self = [super init];
    if (self) {
        _timerStorage = timerStorage;
        _adProvider = adProvider;
        _executor = executor;
        _delegateExecutor = delegateExecutor;
    }
    return self;
}

- (void)start
{
    if (self.isStarted) {
        return;
    }
    [self invalidateTimer];
    
    if (![self isResendPeriodOutdated]) {
        return;
    }
    
    if (self.adProvider.isAdvertisingTrackingEnabled) {
        [self fireEvent];
    }
    else {
        [self createTimer];
    }
}

- (void)stop
{
    if (!self.isStarted) {
        return;
    }
    [self invalidateTimer];
}

- (void)invalidateTimer
{
    AMAMultiTimer *timer;
    @synchronized (self) {
        timer = self.timer;
        self.timer = nil;
        self.isStarted = NO;
    }
    
    [timer invalidate];
}

- (void)createTimer
{
    NSArray<NSNumber *> *delays = [self.timerStorage retryPeriod] ?: @[];
    if (delays.count == 0) {
        return;
    }
    
    AMAMultiTimer *multitimer = [[AMAMultiTimer alloc] initWithDelays:delays
                                                             executor:self.executor
                                                             delegate:self];
    
    @synchronized (self) {
        if (self.isStarted) {
            return;
        }
        
        self.timer = multitimer;
        
        self.isStarted = YES;
    }
    [multitimer start];
}

- (BOOL)isResendPeriodOutdated
{
    return self.timerStorage.isResendPeriodOutdated;
}

- (void)fireEvent
{
    [self.delegateExecutor execute:^{
        [self.delegate privacyTimerDidFire:self];
    }];
}

- (void)multitimerDidFire:(AMAMultiTimer *)multitimer
{
    if (!self.isStarted) {
        return;
    }
    
    BOOL isNeedFire = [self.adProvider isAdvertisingTrackingEnabled];
    
    if (isNeedFire) {
        [self invalidateTimer];
        [self fireEvent];
    }
}

@end
