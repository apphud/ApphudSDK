
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMACoreUtilsLogging.h"

@interface AMATimer ()

@property (nonatomic, strong, readwrite) NSDate *startDate;

@property (nonatomic, strong) dispatch_source_t timerSource;
@property (nonatomic, strong) dispatch_queue_t queue;
@property (nonatomic, assign) NSTimeInterval timeout;

@end

@implementation AMATimer

- (instancetype)initWithTimeout:(NSTimeInterval)timeout
{
    return [self initWithTimeout:timeout callbackQueue:nil];
}

- (instancetype)initWithTimeout:(NSTimeInterval)timeout callbackQueue:(dispatch_queue_t)queue
{
    self = [super init];
    if (self != nil) {
        self.timeout = timeout;

        if (queue == nil) {
            queue = dispatch_get_main_queue();
        }
        self.queue = queue;
    }

    return self;
}

- (void)createTimerSourceAndStart
{
    self.timerSource = dispatch_source_create(DISPATCH_SOURCE_TYPE_TIMER, 0, 0, self.queue);
    self.startDate = [NSDate date];
    dispatch_time_t dispatchTime = dispatch_time(DISPATCH_TIME_NOW,
                                                 (int64_t)(self.timeout * NSEC_PER_SEC));

    dispatch_source_set_timer(self.timerSource, dispatchTime, DISPATCH_TIME_FOREVER, 0);

    __weak typeof(self) wself = self;

    dispatch_source_set_event_handler(self.timerSource, ^{
        [wself.delegate timerDidFire:wself];
    });

    dispatch_resume(self.timerSource);

    AMALogInfo(@"Timer started, timeout: %.2f", self.timeout);
}

- (void)start
{
    if (self.timerSource == nil) {
        @synchronized(self) {
            if (self.timerSource == nil) {
                [self createTimerSourceAndStart];
            }
        }
    }
}

- (void)invalidate
{
    if (self.timerSource != nil) {
        @synchronized(self) {
            if (self.timerSource != nil) {
                dispatch_source_cancel(self.timerSource);
                AMALogInfo(@"Timer canceled");
            }
        }
    }
}

- (void)dealloc
{
    [self invalidate];
}

@end
