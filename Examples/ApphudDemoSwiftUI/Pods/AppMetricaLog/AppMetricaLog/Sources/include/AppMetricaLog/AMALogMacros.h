
#import <AppMetricaLog/AppMetricaLog.h>

#define AMALOG_MESSAGE(chn, lvl, btr, fmt, ...) \
        do { [[AMALogFacade sharedLog] logMessageToChannel:chn \
                                                     level:lvl \
                                                      file:__FILE__ \
                                                  function:__PRETTY_FUNCTION__ \
                                                      line:__LINE__ \
                                              addBacktrace:btr \
                                                    format:(fmt), ##__VA_ARGS__];\
        } while (0)

#define AMALogInfoChannel(channel, format, ...) AMALOG_MESSAGE(channel, AMALogLevelInfo, NO, format, ##__VA_ARGS__)
#define AMALogWarnChannel(channel, format, ...) AMALOG_MESSAGE(channel, AMALogLevelWarning, NO, format, ##__VA_ARGS__)
#define AMALogErrorChannel(channel, format, ...) AMALOG_MESSAGE(channel, AMALogLevelError, NO, format, ##__VA_ARGS__)
#define AMALogNotifyChannel(channel, format, ...) AMALOG_MESSAGE(channel, AMALogLevelNotify, NO, format, ##__VA_ARGS__)

// TODO: https://nda.ya.ru/t/e4dab4vU75axJE
#define AMALogAssertChannel(channel, format, ...) do { \
                                                      AMALogErrorChannel(channel, format, ##__VA_ARGS__); \
                                                  } while (0)
/**
 * Macros with predefined levels and implicit channel specification. To use this macro, define `AMA_LOG_CHANNEL` in submodule before importing AMALog.
 * Before calling any of these macros, setup your `AMA_LOG_CHANNEL` in `AMALogConfigurator` with `-setupLogWithChannel:`.
 */
#define AMALogInfo(format, ...) AMALogInfoChannel(AMA_LOG_CHANNEL, format, ##__VA_ARGS__)
#define AMALogWarn(format, ...) AMALogWarnChannel(AMA_LOG_CHANNEL, format, ##__VA_ARGS__)
#define AMALogError(format, ...) AMALogErrorChannel(AMA_LOG_CHANNEL, format, ##__VA_ARGS__)
#define AMALogNotify(format, ...) AMALogNotifyChannel(AMA_LOG_CHANNEL, format, ##__VA_ARGS__)
#define AMALogAssert(format, ...) AMALogAssertChannel(AMA_LOG_CHANNEL, format, ##__VA_ARGS__)

#if AMA_ALLOW_BACKTRACE_LOG
    #define AMALogBacktraceChannel(channel, format, ...) \
        AMALOG_MESSAGE(AMA_LOG_CHANNEL, AMALogLevelInfo, YES, format, ##__VA_ARGS__)
    #define AMALogBacktrace(format, ...) AMALogBacktraceChannel(AMA_LOG_CHANNEL, format, ##__VA_ARGS__)
#else /* AMA_ALLOW_BACKTRACE_LOG */
    #define AMALogBacktraceChannel(channel, format, ...)
    #define AMALogBacktrace(format, ...)
#endif /* AMA_ALLOW_BACKTRACE_LOG */
