
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@implementation AMAFailureDispatcher

+ (void)dispatchError:(NSError *)error withBlock:(void (^)(NSError *))block
{
    if ((block != nil) && (error != nil)) {
        dispatch_async(dispatch_get_global_queue(DISPATCH_QUEUE_PRIORITY_DEFAULT, 0), ^{
            block(error);
        });
    }
}

@end
