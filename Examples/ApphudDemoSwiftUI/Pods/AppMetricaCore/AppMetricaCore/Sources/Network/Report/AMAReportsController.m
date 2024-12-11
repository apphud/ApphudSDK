#import "AMAReportsController.h"

#import "AMAAppMetrica+Internal.h"
#import "AMAEvent.h"
#import "AMAInternalEventsReporter.h"
#import "AMAReportHostProvider.h"
#import "AMAReportPayload.h"
#import "AMAReportPayloadProvider.h"
#import "AMAReportRequest.h"
#import "AMAReportRequestModel.h"
#import "AMARequestModelSplitter.h"
#import "AMATimeoutRequestsController.h"
#import "AMAReportRequestFactory.h"

NSString *const kAMAReportsControllerErrorDomain = @"io.appmetrica.AMAReportController";
static NSUInteger const kAMATooBigRequestSplitSize = 2;

@interface AMAReportsController () <AMAHTTPRequestDelegate, AMAReportPayloadProviderDelegate>

@property (nonatomic, strong, readonly) id<AMAAsyncExecuting> executor;
@property (nonatomic, strong, readonly) id<AMAResettableIterable> hostProvider;
@property (nonatomic, strong, readonly) AMAHTTPRequestsFactory *httpRequestsFactory;
@property (nonatomic, strong, readonly) AMAReportResponseParser *responseParser;
@property (nonatomic, strong, readonly) AMAReportPayloadProvider *payloadProvider;
@property (nonatomic, strong, readonly) AMATimeoutRequestsController *timeoutRequestsController;
@property (nonatomic, strong, readonly) id<AMAReportRequestFactory> reportRequestFactory;

@property (nonatomic, assign) BOOL inProgress;
@property (nonatomic, assign) BOOL isRetryAllowed;
@property (nonatomic, strong) NSMutableArray<AMAReportRequestModel *> *requestModels;
@property (nonatomic, strong) AMAReportRequest *reportRequest;
@property (nonatomic, strong) AMAHTTPRequestor *currentHTTPRequestor;

@end

@implementation AMAReportsController

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting>)executor
       timeoutRequestsController:(AMATimeoutRequestsController *)timeoutRequestsController
            reportRequestFactory:(id<AMAReportRequestFactory>)reportRequestFactory
{
    id<AMAResettableIterable> hostProvider = [[AMAReportHostProvider alloc] init];
    AMAHTTPRequestsFactory *requestsFactory = [[AMAHTTPRequestsFactory alloc] init];
    AMAReportResponseParser *responseParser = [[AMAReportResponseParser alloc] init];
    AMAReportPayloadProvider *payloadProvider = [[AMAReportPayloadProvider alloc] init];
    
    return [self initWithExecutor:executor
                     hostProvider:hostProvider
              httpRequestsFactory:requestsFactory
                   responseParser:responseParser
                  payloadProvider:payloadProvider
        timeoutRequestsController:timeoutRequestsController
             reportRequestFactory:reportRequestFactory];
}

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting>)executor
                    hostProvider:(id<AMAResettableIterable>)hostProvider
             httpRequestsFactory:(AMAHTTPRequestsFactory *)httpRequestsFactory
                  responseParser:(AMAReportResponseParser *)responseParser
                 payloadProvider:(AMAReportPayloadProvider *)payloadProvider
       timeoutRequestsController:(AMATimeoutRequestsController *)timeoutRequestsController
            reportRequestFactory:(id<AMAReportRequestFactory>)reportRequestFactory
{
    self = [super init];
    if (self != nil) {
        _executor = executor;
        _hostProvider = hostProvider;
        _httpRequestsFactory = httpRequestsFactory;
        _responseParser = responseParser;
        _payloadProvider = payloadProvider;
        _payloadProvider.delegate = self;
        _requestModels = [NSMutableArray array];
        _timeoutRequestsController = timeoutRequestsController;
        _reportRequestFactory = reportRequestFactory;
    }
    return self;
}

#pragma mark - Public -

- (void)reportRequestModelsFromArray:(NSArray<AMAReportRequestModel *> *)requestModels
{
    if (requestModels.count == 0) {
        return;
    }

    [self.executor execute:^{
        [self.requestModels addObjectsFromArray:requestModels];
        if (self.inProgress == NO) {
            self.inProgress = YES;
            [self performNextRequest];
        }
    }];
}

- (void)cancelPendingRequests
{
    [self.executor execute:^{
        self.isRetryAllowed = NO;
        [self.requestModels removeAllObjects];
    }];
}

#pragma mark - Private -

- (void)performNextRequest
{
    AMAReportRequestModel *requestModel = self.requestModels.firstObject;
    if (requestModel != nil) {
        if ([self.timeoutRequestsController isAllowed] == NO) {
            [self completeWithTimeoutError];
        }
        else {
            AMAApplicationState *newState = [AMAApplicationStateManager stateWithFilledEmptyValues:requestModel.appState];
            requestModel = [requestModel copyWithAppState:newState];
            NSError *error = nil;
            AMAReportPayload *payload = [self.payloadProvider generatePayloadWithRequestModel:requestModel error:&error];
            [self.requestModels removeObjectAtIndex:0];
            if (error != nil) {
                return [self handlePayloadProviderError:error];
            }
            
            [self.hostProvider reset];
            [self cancelCurrentHTTPRequest];
            NSString *requestIdentifier = [self.delegate reportsControllerNextRequestIdentifierForController:self];
            AMAReportRequest *request = [self.reportRequestFactory reportRequestWithPayload:payload
                                                                          requestIdentifier:requestIdentifier];
            AMAHTTPRequestor *httpRequestor = [self httpRequestorForReportRequest:request];
            if (httpRequestor != nil) {
                self.reportRequest = request;
                self.currentHTTPRequestor = httpRequestor;
                self.isRetryAllowed = YES;
                AMALogInfo(@"Sending to apiKey %@ host %@ events %@", requestModel.apiKey,
                                   request.host, requestModel.events);
                [httpRequestor start];
            }
            else {
                [self completeWithRequestCreationError];
            }
        }
    }
    else {
        [self complete];
        [self.delegate reportsControllerDidFinishWithSuccess:self];
    }
}

- (void)restartCurrentRequest
{
    [self cancelCurrentHTTPRequest];

    if ([self.timeoutRequestsController isAllowed] == NO) {
        [self completeWithTimeoutError];
        return;
    }

    AMAReportRequest *request = self.reportRequest;
    if (request != nil) {
        AMAHTTPRequestor *httpRequestor = [self httpRequestorForReportRequest:request];
        if (httpRequestor != nil) {
            self.currentHTTPRequestor = httpRequestor;
            AMALogInfo(@"Retrying sending");
            [httpRequestor start];
        }
        else {
            [self completeWithRequestCreationError];
        }
    }
    else {
        [self performNextRequest];
    }
}

- (void)splitCurrentRequest
{
    NSArray *payloads = [AMARequestModelSplitter splitRequestModel:self.reportRequest.reportPayload.model
                                                           inParts:kAMATooBigRequestSplitSize];
    NSError *fallbackError = [self errorWithCode:AMAReportsControllerErrorRequestEntityTooLarge];

    if (payloads.count == 1) {
        [self completeWithError:fallbackError];
        return;
    }

    NSError __block *error = nil;
    [payloads enumerateObjectsWithOptions:NSEnumerationReverse usingBlock:^(id obj, NSUInteger idx, BOOL *stop) {
        if (idx == 0) {
            AMAReportPayload *payload = [self.payloadProvider generatePayloadWithRequestModel:obj error:&error];
            self.reportRequest = [self.reportRequestFactory reportRequestWithPayload:payload
                                                                   requestIdentifier:self.reportRequest.requestIdentifier];
        }
        else {
            [self.requestModels insertObject:obj atIndex:0];
        }
    }];

    if (error != nil) {
        [self handlePayloadProviderError:error];
        return;
    }

    [self retryIfPossibleWithHostProvider:nil fallbackError:fallbackError];
}

- (AMAHTTPRequestor *)httpRequestorForReportRequest:(AMAReportRequest *)request
{
    NSString *host = self.hostProvider.current;
    if ([host length] == 0) {
        AMALogWarn(@"Host is empty, failed to perform request: %@", request);
        return nil;
    }
    
    request.host = host;
    AMAHTTPRequestor *httpRequestor = [self.httpRequestsFactory requestorForRequest:request];
    httpRequestor.delegate = self;
    httpRequestor.delegateExecutor = self.executor;
    return httpRequestor;
}

- (void)cancelCurrentHTTPRequest
{
    [self.currentHTTPRequestor cancel];
    self.currentHTTPRequestor = nil;
}

- (void)retryIfPossibleWithHostProvider:(id<AMAResettableIterable>)hostProvider fallbackError:(NSError *)error
{
    if (self.isRetryAllowed) {
        BOOL nextHostExists = (hostProvider != nil && hostProvider.next == nil) == NO;
        if (nextHostExists == NO) {
            if (error != nil && error.code == AMAReportsControllerErrorOther) {
                [self.timeoutRequestsController reportOfFailure];
            }
            [self completeWithError:error];
        }
        else {
            [self restartCurrentRequest];
        }
    }
    else {
        [self completeWithError:error];
    }
}

- (void)complete
{
    [self cancelPendingRequests];
    [self cancelCurrentHTTPRequest];
    self.reportRequest = nil;
    self.currentHTTPRequestor = nil;
    self.inProgress = NO;
}

- (void)completeWithError:(NSError *)error
{
    AMAReportRequestModel *model = self.reportRequest.reportPayload.model;
    [self complete];
    [self.delegate reportsController:self didFailRequest:model withError:error];
}

- (void)completeWithRequestCreationError
{
    AMALogError(@"Failed to create report request");
    [self completeWithError:[self otherError]];
}

- (void)completeWithTimeoutError
{
    AMALogError(@"Report requests have exceeded retries count");
    [self completeWithError:[self errorWithCode:AMAReportsControllerErrorTimeout]];
}

- (NSError *)errorWithCode:(AMAReportsControllerErrorCode)code
{
    return [NSError errorWithDomain:kAMAReportsControllerErrorDomain code:code userInfo:nil];
}

- (NSError *)otherError
{
    return [self errorWithCode:AMAReportsControllerErrorOther];
}

- (void)handlePayloadProviderError:(NSError *)error
{
    BOOL allSessionsAreEmpty = [error.domain isEqualToString:kAMAReportPayloadProviderErrorDomain]
        && error.code == AMAReportPayloadProviderErrorAllSessionsAreEmpty;
    NSError *controllerError = nil;
    if (allSessionsAreEmpty) {
        controllerError = [self errorWithCode:AMAReportsControllerErrorBadRequest];
    }
    else {
        controllerError = [self errorWithCode:AMAReportsControllerErrorOther];
    }
    error = [AMAErrorUtilities errorByAddingUnderlyingError:error
                                                   toError:controllerError];
    [self completeWithError:error];
}

- (void)processSuccessfulResponse:(NSHTTPURLResponse *)response data:(NSData *)data
{
    AMAReportResponse *reportResponse = [self.responseParser responseForData:data];
    if (reportResponse.status == AMAReportResponseStatusAccepted) {
        [self.delegate reportsController:self didReportRequest:self.reportRequest.reportPayload.model];
        [self performNextRequest];
    }
    else {
        [self retryIfPossibleWithHostProvider:self.hostProvider
                                fallbackError:[self errorWithCode:AMAReportsControllerErrorJsonStatusUnknown]];
    }
}

#pragma mark - AMAHTTPRequestOperationDelegate

- (void)httpRequestor:(AMAHTTPRequestor *)requestor didFinishWithData:(NSData *)data response:(NSHTTPURLResponse *)response
{
    switch (response.statusCode) {
        case 200:
            [self.timeoutRequestsController reportOfSuccess];
            [self processSuccessfulResponse:response data:data];
            break;

        case 400:
            [self.timeoutRequestsController reportOfSuccess];
            [self completeWithError:[self errorWithCode:AMAReportsControllerErrorBadRequest]];
            break;

        case 413:
            [self.timeoutRequestsController reportOfSuccess];
            [self splitCurrentRequest];
            break;

        default:
            [self retryIfPossibleWithHostProvider:self.hostProvider fallbackError:[self otherError]];
            break;
    }
}

- (void)httpRequestor:(AMAHTTPRequestor *)requestor didFinishWithError:(NSError *)error response:(NSHTTPURLResponse *)response
{
    NSError *internalError = [AMAErrorUtilities errorByAddingUnderlyingError:error toError:[self otherError]];
    [self retryIfPossibleWithHostProvider:self.hostProvider fallbackError:internalError];
}

#pragma mark - AMAReportPayloadProviderDelegate

- (void)reportPayloadProvider:(AMAReportPayloadProvider *)provider didFailedToReadFileOfEvent:(AMAEvent *)event
{
    [[AMAAppMetrica sharedInternalEventsReporter] reportEventFileNotFoundForEventWithType:event.type];
}

@end
