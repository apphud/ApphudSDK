
#import "AMAProxyReportsController.h"
#import "AMAReportHostProvider.h"
#import "AMATrackingHostProvider.h"
#import "AMAReportPayloadProvider.h"
#import "AMAReportRequest.h"
#import "AMAReportRequestModel.h"
#import "AMARequestModelSplitter.h"
#import "AMATimeoutRequestsController.h"
#import "AMAReportRequestFactory.h"
#import "AMAEvent.h"

typedef enum {
    AMAProxyReportsStateNotStarted,
    AMAProxyReportsStateInProgress,
    AMAProxyReportsStateError,
    AMAProxyReportsStateCompleted
} AMAProxyReportsState;

@interface AMAProxyReportsController () <AMAReportsControllerDelegate>

@property (nonnull, nonatomic, strong, readonly) id<AMAReportsControlling> regularController;
@property (nonnull, nonatomic, strong, readonly) id<AMAReportsControlling> trackingController;

@property (nullable, nonatomic, strong) NSError *regularError;
@property (nullable, nonatomic, strong) NSError *trackingError;

@property (nonatomic) AMAProxyReportsState regularState;
@property (nonatomic) AMAProxyReportsState trackingState;

@end

@implementation AMAProxyReportsController

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting>)executor
 reportTimeoutRequestsController:(AMATimeoutRequestsController *)reportTimeoutRequestsController
trackingTimeoutRequestsController:(AMATimeoutRequestsController *)trackingTimeoutRequestsController
{
    id<AMAReportRequestFactory> regularFactory = [[AMARegularReportRequestFactory alloc] init];
    id<AMAResettableIterable> regularHostProvider = [[AMAReportHostProvider alloc] init];
    
    id<AMAReportRequestFactory> trackingFactory = [[AMATrackingReportRequestFactory alloc] init];
    id<AMAResettableIterable> trackingHostProvider = [[AMATrackingHostProvider alloc] init];
    
    AMAHTTPRequestsFactory *requestsFactory = [[AMAHTTPRequestsFactory alloc] init];
    AMAReportResponseParser *responseParser = [[AMAReportResponseParser alloc] init];
    AMAReportPayloadProvider *payloadProvider = [[AMAReportPayloadProvider alloc] init];
    
    AMAReportsController *regularController = [[AMAReportsController alloc] initWithExecutor:executor
                                                                                hostProvider:regularHostProvider
                                                                         httpRequestsFactory:requestsFactory
                                                                              responseParser:responseParser
                                                                             payloadProvider:payloadProvider
                                                                   timeoutRequestsController:reportTimeoutRequestsController
                                                                        reportRequestFactory:regularFactory];
    AMAReportsController *trackingController = [[AMAReportsController alloc] initWithExecutor:executor
                                                                                 hostProvider:trackingHostProvider
                                                                          httpRequestsFactory:requestsFactory
                                                                               responseParser:responseParser
                                                                              payloadProvider:payloadProvider
                                                                    timeoutRequestsController:trackingTimeoutRequestsController
                                                                         reportRequestFactory:trackingFactory];
    
    return [self initWithExecutor:executor
         regularReportsController:regularController
        trackingReportsController:trackingController];
}

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting>)executor
        regularReportsController:(id<AMAReportsControlling>)regularReportsController
       trackingReportsController:(id<AMAReportsControlling>)trackingReportsController
{
    self = [super init];
    if (self != nil) {
        _regularController = regularReportsController;
        _trackingController = trackingReportsController;
    }
    return self;
}

- (void)reportRequestModelsFromArray:(NSArray<AMAReportRequestModel *> *)requestModels 
{
    if (requestModels.count == 0) {
        return;
    }
    
    self.regularError = nil;
    self.trackingError = nil;
    
    NSMutableArray<AMAReportRequestModel *> *regularModels = [NSMutableArray arrayWithCapacity:requestModels.count];
    NSMutableArray<AMAReportRequestModel *> *trackingModels = [NSMutableArray array];
    
    for (AMAReportRequestModel *model in requestModels) {
        AMAReportRequestModel *regular = model;
        AMAReportRequestModel *tracking = [AMARequestModelSplitter extractTrackingRequestModelFromModel:&regular];
        
        [regularModels addObject:regular];
        if (tracking != nil) {
            [trackingModels addObject:tracking];
        }
    }
    
    
    if (regularModels.count != 0) {
        self.regularState = AMAProxyReportsStateInProgress;
        [self.regularController reportRequestModelsFromArray:regularModels];
    }
    else {
        self.regularState = AMAProxyReportsStateCompleted;
    }
    
    if (trackingModels.count != 0) {
        self.trackingState = AMAProxyReportsStateInProgress;
        [self.trackingController reportRequestModelsFromArray:trackingModels];
    }
    else {
        self.trackingState = AMAProxyReportsStateCompleted;
    }
    
}

- (void)cancelPendingRequests 
{
    [self.regularController cancelPendingRequests];
    [self.trackingController cancelPendingRequests];
}

- (void)setDelegate:(id<AMAReportsControllerDelegate>)delegate
{
    _delegate = delegate;
    
    _regularController.delegate = self;
    _trackingController.delegate = self;
}

- (void)reportsController:(nonnull id<AMAReportsControlling>)controller 
           didFailRequest:(nonnull AMAReportRequestModel *)requestModel
                withError:(nonnull NSError *)error
{
    [self.delegate reportsController:self didFailRequest:requestModel withError:error];
}

- (void)reportsController:(nonnull id<AMAReportsControlling>)controller didReportRequest:(nonnull AMAReportRequestModel *)requestModel 
{
    [self.delegate reportsController:self didReportRequest:requestModel];
}

- (void)reportsControllerDidFinishWithSuccess:(nonnull id<AMAReportsControlling>)controller 
{
    if (controller == self.regularController) {
        self.regularState = AMAProxyReportsStateCompleted;
    }
    else if (controller == self.trackingController) {
        self.trackingState = AMAProxyReportsStateCompleted;
    }
    
    BOOL isRegularSuccess = self.regularState == AMAProxyReportsStateCompleted ||
        self.regularState == AMAProxyReportsStateNotStarted;
    BOOL isTrackingSuccess = self.trackingState == AMAProxyReportsStateCompleted ||
        self.trackingState == AMAProxyReportsStateNotStarted;
    
    if (isRegularSuccess && isTrackingSuccess) {
        [self.delegate reportsControllerDidFinishWithSuccess:self];
    }
}

- (nonnull NSString *)reportsControllerNextRequestIdentifierForController:(nonnull id<AMAReportsControlling>)controller 
{
    return [self.delegate reportsControllerNextRequestIdentifierForController:self];
}

@end
