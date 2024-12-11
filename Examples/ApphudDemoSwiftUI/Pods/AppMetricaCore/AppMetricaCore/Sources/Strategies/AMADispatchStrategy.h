
#import <Foundation/Foundation.h>
#import "AMADispatchStrategyDelegate.h"

@class AMAReporterStorage;
@protocol AMAReportExecutionConditionChecker;
@class AMAStartupController;

NS_ASSUME_NONNULL_BEGIN

@interface AMADispatchStrategy : NSObject

@property (nonatomic, strong, readonly) AMAReporterStorage *storage;
@property (nonatomic, weak, readonly) id<AMADispatchStrategyDelegate> delegate;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithDelegate:(nullable id<AMADispatchStrategyDelegate>)delegate
                         storage:(AMAReporterStorage *)storage
       executionConditionChecker:(id<AMAReportExecutionConditionChecker>)executionConditionChecker NS_DESIGNATED_INITIALIZER;

- (void)start;
- (void)shutdown;

- (void)triggerDispatch;
- (void)restart;
- (BOOL)canBeExecuted:(AMAStartupController *)startupController;

@end

NS_ASSUME_NONNULL_END
