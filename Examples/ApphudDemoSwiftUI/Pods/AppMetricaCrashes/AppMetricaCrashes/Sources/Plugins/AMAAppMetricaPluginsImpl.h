
#import <Foundation/Foundation.h>
#import "AMAAppMetricaPlugins.h"

@protocol AMAAppMetricaPluginReporting;

@interface AMAAppMetricaPluginsImpl : NSObject <AMAAppMetricaPlugins>

- (void)setupCrashReporter:(id<AMAAppMetricaPluginReporting>)crashReporter;

@end
