
#import "AMACore.h"
#import "AMAExtensionsReportExecutionConditionProvider.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAStartupParametersConfiguration.h"

@interface AMAExtensionsReportExecutionConditionProvider ()

@property (nonatomic, strong, readonly) AMAMetricaConfiguration *configuration;

@end

@implementation AMAExtensionsReportExecutionConditionProvider

- (instancetype)init
{
    return [self initWithConfiguration:[AMAMetricaConfiguration sharedInstance]];
}

- (instancetype)initWithConfiguration:(AMAMetricaConfiguration *)configuration
{
    self = [super init];
    if (self != nil) {
        _configuration = configuration;
    }
    return self;
}

- (BOOL)enabled
{
    return self.configuration.startup.extensionsCollectingEnabled;
}

- (NSTimeInterval)launchDelay
{
    NSTimeInterval delay = [AMATimeUtilities intervalWithNumber:self.configuration.startup.extensionsCollectingLaunchDelay
                                                defaultInterval:3.0];
    return delay;
}

- (id<AMAExecutionCondition>)executionCondition
{
    NSTimeInterval interval = [AMATimeUtilities intervalWithNumber:self.configuration.startup.extensionsCollectingInterval
                                                   defaultInterval:24.0 * 3600.0];
    return [[AMAIntervalExecutionCondition alloc] initWithLastExecuted:self.configuration.persistent.extensionsLastReportDate
                                                              interval:interval
                                                   underlyingCondition:nil];
}

- (void)executed
{
    self.configuration.persistent.extensionsLastReportDate = [NSDate date];
}

@end
