
#ifndef AMA_RELEASE
#define AMA_RELEASE 0
#endif

#if AMA_RELEASE

#define AMA_ALLOW_DESCRIPTIONS 0
#define AMA_ALLOW_BACKTRACE_LOG 0

#else /* AMA_RELEASE */

#define AMA_ALLOW_DESCRIPTIONS 1

#ifndef NDEBUG
#define AMA_ALLOW_BACKTRACE_LOG 1
#else /* NDEBUG */
#define AMA_ALLOW_BACKTRACE_LOG 0
#endif /* NDEBUG */

#endif /* AMA_RELEASE */

#ifdef AMA_LOG_CHANNEL
#undef AMA_LOG_CHANNEL
#endif /* AMA_LOG_CHANNEL */

#define AMA_LOG_CHANNEL @"AppMetricaPlatform"

#import <AppMetricaLog/AppMetricaLog.h>
