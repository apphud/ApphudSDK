
#import <Foundation/Foundation.h>
#import "AMAStartupCompletionObserving.h"

@class AMAStartupParametersConfiguration;
@class AMAReporter;
@protocol AMAAsyncExecuting;
@class AMADeepLinkController;

@interface AMAAppOpenWatcher : NSObject

- (instancetype)initWithNotificationCenter:(NSNotificationCenter *)center;
- (void)startWatchingWithDeeplinkController:(AMADeepLinkController *)controller;

@end
