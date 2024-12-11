
#import <AppMetricaLog/AppMetricaLog.h>

@class AMALogMessage;

@interface AMALogMessageFactory : NSObject

- (AMALogMessage *)messageWithLevel:(AMALogLevel)level
                            channel:(AMALogChannel)channel
                               file:(char const *)file
                           function:(char const *)function
                               line:(NSUInteger)line
                       addBacktrace:(BOOL)addBacktrace
                             format:(NSString *)format
                               args:(va_list)args;

@end
