#if __has_include("AppMetricaCoreExtension.h")
    #import "AMAAdProviding.h"
    #import "AMAAppMetricaExtended.h"
    #import "AMAAppMetricaExtendedReporting.h"
    #import "AMAApplicationStateManager.h"
    #import "AMAEnvironmentContainer.h"
    #import "AMAEventFlushableDelegate.h"
    #import "AMAEventPollingDelegate.h"
    #import "AMAExtendedStartupObserving.h"
    #import "AMAModuleActivationConfiguration.h"
    #import "AMAModuleActivationDelegate.h"
    #import "AMAReporterStorageControlling.h"
    #import "AMAServiceConfiguration.h"
#else
    #import <AppMetricaCoreExtension/AMAAdProviding.h>
    #import <AppMetricaCoreExtension/AMAAppMetricaExtended.h>
    #import <AppMetricaCoreExtension/AMAAppMetricaExtendedReporting.h>
    #import <AppMetricaCoreExtension/AMAApplicationStateManager.h>
    #import <AppMetricaCoreExtension/AMAEnvironmentContainer.h>
    #import <AppMetricaCoreExtension/AMAEventFlushableDelegate.h>
    #import <AppMetricaCoreExtension/AMAEventPollingDelegate.h>
    #import <AppMetricaCoreExtension/AMAExtendedStartupObserving.h>
    #import <AppMetricaCoreExtension/AMAModuleActivationConfiguration.h>
    #import <AppMetricaCoreExtension/AMAModuleActivationDelegate.h>
    #import <AppMetricaCoreExtension/AMAReporterStorageControlling.h>
    #import <AppMetricaCoreExtension/AMAServiceConfiguration.h>
#endif
