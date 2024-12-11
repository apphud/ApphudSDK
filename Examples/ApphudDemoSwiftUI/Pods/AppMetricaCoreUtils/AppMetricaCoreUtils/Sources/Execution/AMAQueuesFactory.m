
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMACoreUtilsLogging.h"

@implementation AMAQueuesFactory

+ (dispatch_queue_t)serialQueueForIdentifierObject:(NSObject *)identifierObject domain:(NSString *)domain
{
    NSArray *queueNameComponents = @[
        domain,
        NSStringFromClass(identifierObject.class),
        @"Queue"
    ];
    NSString *queueName = [queueNameComponents componentsJoinedByString:@"."];
    const char *queueNameC = [queueName cStringUsingEncoding:NSUTF8StringEncoding];
    dispatch_queue_t queue = dispatch_queue_create(queueNameC, DISPATCH_QUEUE_SERIAL);
    AMALogInfo(@"Queue created: %@", queueName);
    return queue;
}

@end
