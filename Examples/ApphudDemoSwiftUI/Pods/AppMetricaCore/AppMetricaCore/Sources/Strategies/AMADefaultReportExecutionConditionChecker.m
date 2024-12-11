
#import "AMADefaultReportExecutionConditionChecker.h"
#import "AMAStartupController.h"

@implementation AMADefaultReportExecutionConditionChecker

- (BOOL)canBeExecuted:(AMAStartupController *)startupController
{
    if (startupController.upToDate == NO) {
        [startupController update];
    }
    return startupController.upToDate;
}


@end
