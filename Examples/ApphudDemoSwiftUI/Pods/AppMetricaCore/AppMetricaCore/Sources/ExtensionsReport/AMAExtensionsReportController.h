
#import <Foundation/Foundation.h>
#import "AMAStartupCompletionObserving.h"

@class AMAInternalEventsReporter;
@class AMAExtensionsReportExecutionConditionProvider;
@class AMAExtensionReportProvider;
@protocol AMADelayedExecuting;

@interface AMAExtensionsReportController : NSObject <AMAStartupCompletionObserving>

- (instancetype)initWithReporter:(AMAInternalEventsReporter *)reporter
               conditionProvider:(AMAExtensionsReportExecutionConditionProvider *)conditionProvider
                        provider:(AMAExtensionReportProvider *)provider
                        executor:(id<AMADelayedExecuting>)executor;

- (void)reportIfNeeded;

@end
