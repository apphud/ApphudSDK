
#import <AppMetricaLog/AppMetricaLog.h>

NS_ASSUME_NONNULL_BEGIN

@class AMALogOutput;

typedef NS_OPTIONS(NSInteger, AMALogLevel) {
    AMALogLevelNone    = 1 << 0,
    AMALogLevelInfo    = 1 << 1,
    AMALogLevelWarning = 1 << 2,
    AMALogLevelError   = 1 << 3,
    AMALogLevelNotify  = 1 << 4,
} NS_SWIFT_NAME(LogLevel);

NS_SWIFT_NAME(LogFacade)
@interface AMALogFacade : NSObject

+ (instancetype)sharedLog;

- (instancetype)initWithAsyncLogQueue:(dispatch_queue_t)queue;

- (void)addOutput:(AMALogOutput *)output;
- (void)removeOutput:(AMALogOutput *)output;

- (void)logMessageToChannel:(AMALogChannel)channel
                      level:(AMALogLevel)level
                       file:(const char *)file
                   function:(const char *)function
                       line:(NSUInteger)line
               addBacktrace:(BOOL)addBacktrace
                     format:(NSString *)format, ... NS_FORMAT_FUNCTION(7, 8);

- (NSArray *)outputsWithChannel:(AMALogChannel)channel;

@end

NS_ASSUME_NONNULL_END
