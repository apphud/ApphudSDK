
#import "AMACrashReportingStateNotifier.h"

NSString *const kAMACrashReportingStateEnabledKey = @"appmetrica_crash_enabled";
NSString *const kAMACrashReportingStateCrashedLastLaunchKey = @"appmetrica_crash_crashed_last_launch";

static NSString *const kAMACompletionQueue = @"queue";
static NSString *const kAMACompletionBlock = @"block";

@interface AMACrashReportingStateNotifier ()

@property (nonatomic, strong) NSMutableArray *callbacks;

@end

@implementation AMACrashReportingStateNotifier

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _callbacks = [NSMutableArray array];
    }
    return self;
}

- (void)addObserverWithCompletionQueue:(dispatch_queue_t)completionQueue
                       completionBlock:(AMACrashReportingStateCompletionBlock)completionBlock
{
    if (completionBlock == nil) {
        return;
    }
    @synchronized (self) {
        [self.callbacks addObject:@{
            kAMACompletionQueue: completionQueue ?: dispatch_get_main_queue(),
            kAMACompletionBlock: completionBlock,
        }];
    }
}

- (void)notifyWithEnabled:(BOOL)enabled crashedLastLaunch:(NSNumber *)crashedLastLaunch
{
    NSArray *callbackToProcess = nil;
    @synchronized (self) {
        callbackToProcess = [self.callbacks copy];
        [self.callbacks removeAllObjects];
    }

    if (callbackToProcess.count > 0) {
        NSMutableDictionary *mutableState = [NSMutableDictionary dictionary];
        mutableState[kAMACrashReportingStateEnabledKey] = @(enabled);
        mutableState[kAMACrashReportingStateCrashedLastLaunchKey] = crashedLastLaunch;
        NSDictionary *state = [mutableState copy];

        for (NSDictionary *callbackParameters in callbackToProcess) {
            dispatch_queue_t queue = callbackParameters[kAMACompletionQueue];
            AMACrashReportingStateCompletionBlock block = callbackParameters[kAMACompletionBlock];
            dispatch_async(queue, ^{
                block(state);
            });
        }
    }
}

@end
