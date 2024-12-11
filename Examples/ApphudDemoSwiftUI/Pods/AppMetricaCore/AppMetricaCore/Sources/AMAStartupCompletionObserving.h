
#import <Foundation/Foundation.h>

@class AMAStartupParametersConfiguration;

@protocol AMAStartupCompletionObserving<NSObject>

- (void)startupUpdateCompletedWithConfiguration:(AMAStartupParametersConfiguration *)configuration;

@optional
- (void)startupUpdateFailedWithError:(NSError *)error;

@end
