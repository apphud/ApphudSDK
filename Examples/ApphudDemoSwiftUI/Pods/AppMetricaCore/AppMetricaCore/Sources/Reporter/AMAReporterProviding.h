
#import <Foundation/Foundation.h>

@protocol AMAAppMetricaReporting;

@protocol AMAReporterProviding <NSObject>

- (id<AMAAppMetricaReporting>)reporter;

@end
