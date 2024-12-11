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

#import "AMAApplicationState.h"
#import "AMAApplicationStateKeys.h"
#import "AMAPlatformDescription.h"
#import "AMAPlatformLocaleState.h"
#import "AMAVersion.h"
#import "AppMetricaPlatform.h"

FOUNDATION_EXPORT double AppMetricaPlatformVersionNumber;
FOUNDATION_EXPORT const unsigned char AppMetricaPlatformVersionString[];

