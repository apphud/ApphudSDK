
#if __has_include("AppMetricaCrashes.h")
    #import "AMAAppMetricaCrashReporting.h"
    #import "AMAAppMetricaCrashes.h"
    #import "AMAAppMetricaCrashesConfiguration.h"
    #import "AMAAppMetricaPluginReporting.h"
    #import "AMAAppMetricaPlugins.h"
    #import "AMAError.h"
    #import "AMAErrorRepresentable.h"
    #import "AMAExtendedCrashProcessing.h"
    #import "AMAPluginErrorDetails.h"
    #import "AMAStackTraceElement.h"
#else
    #import <AppMetricaCrashes/AMAAppMetricaCrashReporting.h>
    #import <AppMetricaCrashes/AMAAppMetricaCrashes.h>
    #import <AppMetricaCrashes/AMAAppMetricaCrashesConfiguration.h>
    #import <AppMetricaCrashes/AMAAppMetricaPluginReporting.h>
    #import <AppMetricaCrashes/AMAAppMetricaPlugins.h>
    #import <AppMetricaCrashes/AMAError.h>
    #import <AppMetricaCrashes/AMAErrorRepresentable.h>
    #import <AppMetricaCrashes/AMAExtendedCrashProcessing.h>
    #import <AppMetricaCrashes/AMAPluginErrorDetails.h>
    #import <AppMetricaCrashes/AMAStackTraceElement.h>
#endif
