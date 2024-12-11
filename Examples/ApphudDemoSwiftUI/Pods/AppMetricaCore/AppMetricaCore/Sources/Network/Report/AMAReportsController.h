
#import <Foundation/Foundation.h>

@protocol AMAAsyncExecuting;
@protocol AMAResettableIterable;
@protocol AMAReportRequestFactory;
@class AMAHTTPRequestsFactory;
@class AMAReportRequest;
@class AMAReportsController;
@class AMAReportResponseParser;
@class AMAReportRequestModel;
@class AMAIncrementableValueStorage;
@class AMAReportPayloadProvider;
@class AMATimeoutRequestsController;
@class AMAReportHostProvider;

NS_ASSUME_NONNULL_BEGIN

extern NSErrorDomain const kAMAReportsControllerErrorDomain;

typedef NS_ERROR_ENUM(kAMAReportsControllerErrorDomain, AMAReportsControllerErrorCode) {
    AMAReportsControllerErrorOther,
    AMAReportsControllerErrorJsonStatusUnknown,
    AMAReportsControllerErrorBadRequest,
    AMAReportsControllerErrorRequestEntityTooLarge,
    AMAReportsControllerErrorTimeout,
};

@protocol AMAReportsControlling;

@protocol AMAReportsControllerDelegate <NSObject>

@required
- (NSString *)reportsControllerNextRequestIdentifierForController:(id<AMAReportsControlling>)controller;

- (void)reportsControllerDidFinishWithSuccess:(id<AMAReportsControlling>)controller;

- (void)reportsController:(id<AMAReportsControlling>)controller
         didReportRequest:(AMAReportRequestModel *)requestModel;
- (void)reportsController:(id<AMAReportsControlling>)controller
           didFailRequest:(AMAReportRequestModel *)requestModel
                withError:(NSError *)error;

@end

NS_SWIFT_NAME(ReportsControlling)
@protocol AMAReportsControlling <NSObject>

@required
@property (nullable, nonatomic, weak) id<AMAReportsControllerDelegate> delegate;
- (void)reportRequestModelsFromArray:(NSArray<AMAReportRequestModel *> *)requestModels;
- (void)cancelPendingRequests;

@end


NS_SWIFT_NAME(ReportsController)
@interface AMAReportsController : NSObject <AMAReportsControlling>

@property (nullable, nonatomic, weak) id<AMAReportsControllerDelegate> delegate;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting>)executor
       timeoutRequestsController:(AMATimeoutRequestsController *)timeoutRequestsController
            reportRequestFactory:(id<AMAReportRequestFactory>)reportRequestFactory;
- (instancetype)initWithExecutor:(id<AMAAsyncExecuting>)executor
                    hostProvider:(id<AMAResettableIterable>)hostProvider
             httpRequestsFactory:(AMAHTTPRequestsFactory *)httpRequestsFactory
                  responseParser:(AMAReportResponseParser *)responseParser
                 payloadProvider:(AMAReportPayloadProvider *)payloadProvider
       timeoutRequestsController:(AMATimeoutRequestsController *)timeoutRequestsController
            reportRequestFactory:(id<AMAReportRequestFactory>)reportRequestFactory;

- (void)reportRequestModelsFromArray:(NSArray<AMAReportRequestModel *> *)requestModels;
- (void)cancelPendingRequests;

@end

NS_ASSUME_NONNULL_END
