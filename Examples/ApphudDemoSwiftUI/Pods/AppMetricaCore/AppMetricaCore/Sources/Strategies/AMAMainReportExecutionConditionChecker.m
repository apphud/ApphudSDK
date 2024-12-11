
#import "AMAMainReportExecutionConditionChecker.h"
#import "AMAStartupController.h"
#import "AMAAttributionController.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"

@implementation AMAMainReportExecutionConditionChecker

- (BOOL)canBeExecuted:(AMAStartupController *)startupController
{
    if (startupController.upToDate == NO) {
        [startupController update];
    }

    return startupController.upToDate && [AMAMetricaConfiguration sharedInstance].persistent.checkedInitialAttribution;
}


@end
