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

#import "AMAAppMetricaCrashes.h"
#import "AMAAppMetricaCrashesConfiguration.h"
#import "AMAAppMetricaCrashReporting.h"
#import "AMAAppMetricaPluginReporting.h"
#import "AMAAppMetricaPlugins.h"
#import "AMAError.h"
#import "AMAErrorRepresentable.h"
#import "AMAExtendedCrashProcessing.h"
#import "AMAPluginErrorDetails.h"
#import "AMAStackTraceElement.h"
#import "AppMetricaCrashes.h"

FOUNDATION_EXPORT double AppMetricaCrashesVersionNumber;
FOUNDATION_EXPORT const unsigned char AppMetricaCrashesVersionString[];

