
#import <AppMetricaLog/AppMetricaLog.h>

@protocol AMALogMiddleware <NSObject>

- (BOOL)isAsyncLoggingAcceptable;
- (void)logMessage:(NSString *)message level:(AMALogLevel)level;

@end
