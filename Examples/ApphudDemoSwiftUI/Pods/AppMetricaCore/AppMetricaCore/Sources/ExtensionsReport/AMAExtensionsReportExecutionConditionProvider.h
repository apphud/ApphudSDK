
#import <Foundation/Foundation.h>

@protocol AMAExecutionCondition;
@class AMAMetricaConfiguration;

@interface AMAExtensionsReportExecutionConditionProvider : NSObject

@property (nonatomic, assign, readonly) BOOL enabled;
@property (nonatomic, assign, readonly) NSTimeInterval launchDelay;

- (instancetype)initWithConfiguration:(AMAMetricaConfiguration *)configuration;

- (id<AMAExecutionCondition>)executionCondition;
- (void)executed;

@end
