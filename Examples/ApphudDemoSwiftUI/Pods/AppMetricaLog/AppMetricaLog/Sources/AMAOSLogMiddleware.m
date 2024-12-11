
#import "AMAOSLogMiddleware.h"
#import <os/log.h>

@interface AMAOSLogMiddleware ()

@property (nonatomic, strong, readonly) os_log_t log;

@end

@implementation AMAOSLogMiddleware

- (instancetype)initWithCategory:(const char *)category
{
    self = [super init];
    if (self != nil) {
        _log = os_log_create("io.appmetrica", category);
    }
    return self;
}

- (BOOL)isAsyncLoggingAcceptable
{
    return NO;
}

- (os_log_type_t)logTypeForLevel:(AMALogLevel)logLevel
{
    switch (logLevel) {
        case AMALogLevelNone:
            return OS_LOG_TYPE_DEFAULT;
        case AMALogLevelInfo:
            return OS_LOG_TYPE_INFO;
        case AMALogLevelWarning:
            return OS_LOG_TYPE_INFO;
        case AMALogLevelError:
            return OS_LOG_TYPE_ERROR;
        case AMALogLevelNotify:
            return OS_LOG_TYPE_INFO;
    }
}

- (void)logMessage:(NSString *)message level:(AMALogLevel)level
{
    if (message == nil) {
        return;
    }

    os_log_with_type(self.log, [self logTypeForLevel:level], "%{public}@", message);
}

@end
