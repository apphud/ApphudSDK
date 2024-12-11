
#import "AMADispatchStrategiesFactory.h"
#import "AMATimerDispatchStrategy.h"
#import "AMAEventCountDispatchStrategy.h"
#import "AMAUrgentEventCountDispatchStrategy.h"

@implementation AMADispatchStrategiesFactory

+ (NSArray *)strategiesForStorage:(AMAReporterStorage *)storage
                         typeMask:(AMADispatchStrategyMask)typeMask
                         delegate:(id<AMADispatchStrategyDelegate>)delegate
        executionConditionChecker:(id<AMAReportExecutionConditionChecker>)executionConditionChecker
{
    __block NSMutableArray *strategies = [NSMutableArray array];

    static NSDictionary *typeToClassMap = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        typeToClassMap =  @{
                            @(AMADispatchStrategyTypeCount) : [AMAEventCountDispatchStrategy class],
                            @(AMADispatchStrategyTypeTimer) : [AMATimerDispatchStrategy class],
                            @(AMADispatchStrategyTypeUrgent) : [AMAUrgentEventCountDispatchStrategy class]
                            };
    });
    for (NSNumber *strategyType in typeToClassMap.allKeys) {
        if (typeMask & (NSUInteger)strategyType.integerValue) {
            Class strategyClass = typeToClassMap[strategyType];
            AMADispatchStrategy *strategy = [[strategyClass alloc] initWithDelegate:delegate storage:storage executionConditionChecker:executionConditionChecker];
            if (strategy != nil) {
                [strategies addObject:strategy];
            }
        }
    }
    return strategies;
}

+ (NSUInteger)allStrategiesTypesMask
{
    return AMADispatchStrategyTypeCount | AMADispatchStrategyTypeTimer | AMADispatchStrategyTypeUrgent;
}

@end
