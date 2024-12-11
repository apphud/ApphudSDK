
#import <Foundation/Foundation.h>
#import "AMADispatchStrategyMask.h"

@protocol AMADispatchStrategyDelegate;
@protocol AMAReportExecutionConditionChecker;
@class AMAReporterStorage;

@interface AMADispatchStrategiesFactory : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSArray *)strategiesForStorage:(AMAReporterStorage *)storage
                         typeMask:(AMADispatchStrategyMask)typeMask
                         delegate:(id<AMADispatchStrategyDelegate>)delegate
        executionConditionChecker:(id<AMAReportExecutionConditionChecker>)executionConditionChecker;

+ (NSUInteger)allStrategiesTypesMask;

@end
