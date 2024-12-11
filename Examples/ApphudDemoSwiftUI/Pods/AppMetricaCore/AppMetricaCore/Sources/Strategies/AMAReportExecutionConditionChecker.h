
#import <Foundation/Foundation.h>

@class AMAStartupController;

@protocol AMAReportExecutionConditionChecker <NSObject>

- (BOOL)canBeExecuted:(AMAStartupController *)startupController;

@end
