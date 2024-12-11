
#import <Foundation/Foundation.h>

@class AMALocationStorage;
@class AMALocationCollectingConfiguration;
@class AMALocationDispatchStrategy;
@class AMALocationRequestProvider;
@class AMAReportResponseParser;
@class AMATimeoutRequestsController;
@protocol AMACancelableExecuting;

@interface AMALocationDispatcher : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithStorage:(AMALocationStorage *)storage
                  configurtaion:(AMALocationCollectingConfiguration *)configuration
                       executor:(id<AMACancelableExecuting>)executor
              timeoutController:(AMATimeoutRequestsController *)timeoutController;

- (instancetype)initWithStorage:(AMALocationStorage *)storage
                  configurtaion:(AMALocationCollectingConfiguration *)configuration
                       executor:(id<AMACancelableExecuting>)executor
                       strategy:(AMALocationDispatchStrategy *)strategy
                requestProvider:(AMALocationRequestProvider *)requestProvider
                 responseParser:(AMAReportResponseParser *)responseParser
              timeoutController:(AMATimeoutRequestsController *)timeoutController;

- (void)handleLocationAdd;
- (void)handleVisitAdd;

@end
