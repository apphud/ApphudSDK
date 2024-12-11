
#import <Foundation/Foundation.h>
#import <dispatch/dispatch.h>

#import "AMACrashLogging.h"
#import "AMAAppMetricaCrashes.h"

@interface AMACrashReportingStateNotifier : NSObject

- (void)addObserverWithCompletionQueue:(dispatch_queue_t)completionQueue
                       completionBlock:(AMACrashReportingStateCompletionBlock)completionBlock;

- (void)notifyWithEnabled:(BOOL)enabled crashedLastLaunch:(NSNumber *)crashedLastLaunch;

@end
