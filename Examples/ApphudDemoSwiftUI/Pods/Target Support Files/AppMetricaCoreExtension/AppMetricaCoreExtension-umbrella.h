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

#import "AMAAdProviding.h"
#import "AMAApplicationStateManager.h"
#import "AMAAppMetricaExtended.h"
#import "AMAAppMetricaExtendedReporting.h"
#import "AMAEnvironmentContainer.h"
#import "AMAEventFlushableDelegate.h"
#import "AMAEventPollingDelegate.h"
#import "AMAExtendedStartupObserving.h"
#import "AMAModuleActivationConfiguration.h"
#import "AMAModuleActivationDelegate.h"
#import "AMAReporterStorageControlling.h"
#import "AMAServiceConfiguration.h"
#import "AppMetricaCoreExtension.h"

FOUNDATION_EXPORT double AppMetricaCoreExtensionVersionNumber;
FOUNDATION_EXPORT const unsigned char AppMetricaCoreExtensionVersionString[];

