#ifdef __OBJC__
#import <UIKit/UIKit.h>
#else
#ifndef FOUNDATION_EXPORT
#if defined(__cplusplus)
#define FOUNDATION_EXPORT extern "C"
#else
#define FOUNDATION_EXPORT extern
#endif
#endif
#endif

#import "AMALogChannel.h"
#import "AMALogConfigurator.h"
#import "AMALogFacade.h"
#import "AMALogMacros.h"
#import "AppMetricaLog.h"

FOUNDATION_EXPORT double AppMetricaLogVersionNumber;
FOUNDATION_EXPORT const unsigned char AppMetricaLogVersionString[];

