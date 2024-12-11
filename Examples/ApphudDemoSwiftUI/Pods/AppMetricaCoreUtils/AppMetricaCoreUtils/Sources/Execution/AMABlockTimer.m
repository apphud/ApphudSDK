
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMACoreUtilsLogging.h"

@interface AMABlockTimer () <AMATimerDelegate>

@property (nonatomic, strong, readonly) AMATimer *timer;
@property (nonatomic, copy, readonly) AMABlockTimerBlock block;

@end

@implementation AMABlockTimer

- (id)initWithTimeout:(NSTimeInterval)timeout block:(AMABlockTimerBlock)block
{
    return [self initWithTimeout:timeout callbackQueue:nil block:block];
}

- (id)initWithTimeout:(NSTimeInterval)timeout callbackQueue:(dispatch_queue_t)queue block:(AMABlockTimerBlock)block
{
    if (block == nil) {
        AMALogAssert(@"Block can't be nil");
    }
    self = [super init];
    if (self != nil) {
        _timer = [[AMATimer alloc] initWithTimeout:timeout callbackQueue:queue];
        _timer.delegate = self;
        _block = [block copy];
    }
    return self;
}

- (void)start
{
    [self.timer start];
}

- (void)invalidate
{
    [self.timer invalidate];
}

#pragma mark - AMATimerDelegate

- (void)timerDidFire:(AMATimer *)timer
{
    if (self.block != nil) {
        self.block(self);
    }
}

@end
