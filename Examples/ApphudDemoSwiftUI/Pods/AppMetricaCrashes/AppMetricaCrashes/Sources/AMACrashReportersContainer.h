
#import <Foundation/Foundation.h>

@protocol AMAAppMetricaCrashReporting;

@interface AMACrashReportersContainer : NSObject

- (id<AMAAppMetricaCrashReporting>)reporterForAPIKey:(NSString *)apiKey;

- (void)setReporter:(id<AMAAppMetricaCrashReporting>)reporter forAPIKey:(NSString *)apiKey;

@end
