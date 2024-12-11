
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMACoreUtilsLogging.h"

static NSString *const kAppMetricaCoreUtilsDomain = @"io.appmetrica.CoreUtils";

#pragma mark - async queue

@interface AMAExecutor ()

@property (nonatomic, strong) dispatch_queue_t queue;

@end

@implementation AMAExecutor

- (instancetype)init
{
    return [self initWithIdentifier:nil];
}

- (instancetype)initWithQueue:(dispatch_queue_t)queue
{
    self = [super init];
    if (self != nil) {
        _queue = queue;
    }
    return self;
}

- (instancetype)initWithIdentifier:(NSObject *)identifier
{
    if (identifier == nil) {
        identifier = self;
    }
    dispatch_queue_t queue = [AMAQueuesFactory serialQueueForIdentifierObject:identifier
                                                                       domain:kAppMetricaCoreUtilsDomain];
    
    return [self initWithQueue:queue];
}

- (void)execute:(dispatch_block_t)block
{
    AMALogBacktrace(@"Async execution on queue: %@", self.queue);
    dispatch_async(self.queue, ^{
        @autoreleasepool {
            block();
        }
    });
}

- (nullable id)syncExecute:(id _Nullable (^)(void))block
{
    AMALogBacktrace(@"Sync execution on queue: %@", self.queue);
    __block id result = nil;
    dispatch_sync(self.queue, ^{
        @autoreleasepool {
            result = block();
        }
    });
    return result;
}

@end

#pragma mark - delayed

@implementation AMADelayedExecutor

- (void)executeAfterDelay:(NSTimeInterval)delay block:(dispatch_block_t)block
{
    AMALogBacktrace(@"Delayed (%.2f) async execution on queue: %@", delay, self.queue);
    dispatch_after(dispatch_time(DISPATCH_TIME_NOW, (int64_t)(delay * NSEC_PER_SEC)), [self queue], ^{
        @autoreleasepool {
            block();
        }
    });
}

@end

@interface AMACancelableDelayedExecutor ()

@property (nonatomic, strong) NSMutableArray *timers;

@end

@implementation AMACancelableDelayedExecutor

- (instancetype)initWithIdentifier:(NSObject *)identifier
{
    self = [super initWithIdentifier:identifier];
    if (self != nil) {
        _timers = [NSMutableArray array];
    }
    return self;
}

- (void)executeAfterDelay:(NSTimeInterval)delay block:(dispatch_block_t)block
{
    @synchronized (self) {
        AMALogInfo(@"Delayed (%.2f) async execution on queue: %@", delay, self.queue);
        AMABlockTimer *timer = [[AMABlockTimer alloc] initWithTimeout:delay
                                                        callbackQueue:self.queue
                                                                block:[self callbackForBlock:block]];
        [self.timers addObject:timer];
        [timer start];
    }
}

- (AMABlockTimerBlock)callbackForBlock:(dispatch_block_t)block
{
    __weak __typeof(self) weakSelf = self;
    return ^(AMABlockTimer *sender) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf != nil) {
            @synchronized (strongSelf) {
                [strongSelf.timers removeObject:sender];
            }
            if (block != nil) {
                @autoreleasepool {
                    block();
                }
            }
        }
    };
}

- (void)cancelDelayed
{
    NSArray *timers = nil;
    @synchronized (self) {
        AMALogInfo(@"Cancellation of async execution on queue: %@", self.queue);
        timers = [self.timers copy];
        [self.timers removeAllObjects];
    }
    for (AMABlockTimer *timer in timers) {
        [timer invalidate];
    }
}

- (void)dealloc
{
    [self cancelDelayed];
}

@end
