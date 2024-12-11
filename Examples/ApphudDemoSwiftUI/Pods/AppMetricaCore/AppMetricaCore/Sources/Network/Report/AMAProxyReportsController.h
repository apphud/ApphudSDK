
#import <Foundation/Foundation.h>
#import "AMAReportsController.h"

@class AMAProxyReportsController;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(ProxyReportsController)
@interface AMAProxyReportsController : NSObject<AMAReportsControlling>
- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting>)executor
 reportTimeoutRequestsController:(AMATimeoutRequestsController *)reportTimeoutRequestsController
trackingTimeoutRequestsController:(AMATimeoutRequestsController *)trackingTimeoutRequestsController;

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting>)executor
        regularReportsController:(id<AMAReportsControlling>)regularReportsController
       trackingReportsController:(id<AMAReportsControlling>)trackingReportsController;

@property (nullable, nonatomic, weak) id<AMAReportsControllerDelegate> delegate;

@end

NS_ASSUME_NONNULL_END
