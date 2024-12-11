
#import "AMATTYLogMiddleware.h"
#import <sys/uio.h>

@interface AMATTYLogMiddleware () {
    dispatch_semaphore_t _semaphore;
}

@property (nonatomic, assign) int descriptor;

@end

@implementation AMATTYLogMiddleware

- (instancetype)init
{
    return [self initWithOutputDescriptor:STDERR_FILENO];
}

- (instancetype)initWithOutputDescriptor:(int)descriptor
{
    self = [super init];
    if (self) {
        _descriptor = descriptor;
        _semaphore = dispatch_semaphore_create(1);
    }
    return self;
}

- (BOOL)isAsyncLoggingAcceptable
{
    return NO;
}

- (void)logMessage:(NSString *)message level:(AMALogLevel)level
{
    if (message == nil) {
        return;
    }

    dispatch_semaphore_wait(_semaphore, DISPATCH_TIME_FOREVER);

    int iovec_len = 2;
    struct iovec v[iovec_len];

    v[0].iov_base = (void *)[message UTF8String];
    v[0].iov_len = strlen(v[0].iov_base);

    v[1].iov_base = "\n";
    v[1].iov_len = 1;

    writev(self.descriptor, v, iovec_len);

    dispatch_semaphore_signal(_semaphore);
}

@end
