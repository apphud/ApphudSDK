
#import "AMANetworkCore.h"
#import <AppMetricaNetwork/AppMetricaNetwork.h>

NSString *const kAMAHostExchangeRequestProcessorErrorDomain = @"kAMAHostExchangeRequestProcessorErrorDomain";

@interface AMAHostExchangeRequestProcessor () <AMAHTTPRequestDelegate>

@property (nonatomic, strong, readonly) id<AMARequest> request;
@property (nonatomic, strong, readonly) id<AMAAsyncExecuting> executor;
@property (nonatomic, strong, readonly) AMAHTTPRequestsFactory *httpRequestsFactory;
@property (nonatomic, strong, readonly) id<AMAIterable> hostProvider;
@property (nonatomic, strong, readonly) id<AMAHostExchangeResponseValidating> responseValidator;

@property (nonatomic, strong) AMAHTTPRequestor *activeRequestor;
@property (nonatomic, copy) AMAHostExchangeRequestProcessorCallback callback;

@end

@implementation AMAHostExchangeRequestProcessor

- (instancetype)initWithRequest:(id<AMARequest>)request
                       executor:(id<AMAAsyncExecuting>)executor
                   hostProvider:(id<AMAIterable>)hostProvider
              responseValidator:(id<AMAHostExchangeResponseValidating>)responseValidator
{
    return [self initWithRequest:request
                        executor:executor
                    hostProvider:hostProvider
               responseValidator:responseValidator
             httpRequestsFactory:[[AMAHTTPRequestsFactory alloc] init]];
}

- (instancetype)initWithRequest:(id<AMARequest>)request
                       executor:(id<AMAAsyncExecuting>)executor
                   hostProvider:(id<AMAIterable>)hostProvider
              responseValidator:(id<AMAHostExchangeResponseValidating>)responseValidator
            httpRequestsFactory:(AMAHTTPRequestsFactory *)httpRequestsFactory
{
    self = [super init];
    if (self != nil) {
        _request = request;
        _executor = executor;
        _hostProvider = hostProvider;
        _responseValidator = responseValidator;
        _httpRequestsFactory = httpRequestsFactory;
    }
    return self;
}

- (void)processWithCallback:(AMAHostExchangeRequestProcessorCallback)callback
{
    if (self.activeRequestor == nil) {
        __typeof(self) __weak weakSelf = self;
        [self.executor execute:^{
            __typeof(self) strongSelf = weakSelf;
            if (strongSelf != nil && strongSelf.activeRequestor == nil) {
                @synchronized(strongSelf) {
                    strongSelf.callback = callback;
                }
                [strongSelf startRequest];
            }
        }];
    }
}

- (void)startRequest
{
    NSString *host = self.hostProvider.current;
    if (host != nil) {
        self.request.host = host;
        AMAHTTPRequestor *httpRequestor = [self.httpRequestsFactory requestorForRequest:self.request];
        httpRequestor.delegate = self;
        httpRequestor.delegateExecutor = self.executor;
        self.activeRequestor = httpRequestor;
        [httpRequestor start];
    }
    else {
        AMALogWarn(@"Request host is nil");
    }
}

- (void)retryIfPossibleOrCompleteWithError:(NSError *)error
{
    if ([self.hostProvider next] != nil) {
        AMALogInfo(@"Restart diagnostic request with next report host");
        [self startRequest];
    }
    else {
        [self completeWithError:error];
    }
}

- (NSError *)networkError
{
    return [self errorWithCode:AMAHostExchangeRequestProcessorNetworkError];
}

- (NSError *)errorWithCode:(AMAHostExchangeRequestProcessorErrorCode)code
{
    return [NSError errorWithDomain:kAMAHostExchangeRequestProcessorErrorDomain
                               code:code
                           userInfo:nil];
}

- (void)completeWithError:(NSError *)error
{
    AMAHostExchangeRequestProcessorCallback syncCallback = nil;
     @synchronized(self) {
         syncCallback = self.callback;
         self.callback = nil;
     }
     if (syncCallback != nil) {
         syncCallback(error);
     }
}

#pragma mark - AMAHTTPRequestDelegate

- (void)processSuccessfulResponse:(NSHTTPURLResponse *)response data:(NSData *)data
{
    if (self.responseValidator == nil || [self.responseValidator isResponseValidWithData:data]) {
        [self completeWithError:nil];
    }
    else {
        [self retryIfPossibleOrCompleteWithError:[self networkError]];
    }
}

- (void)httpRequestor:(AMAHTTPRequestor *)requestor didFinishWithData:(NSData *)data response:(NSHTTPURLResponse *)response
{
    switch (response.statusCode) {
        case 200:
            [self processSuccessfulResponse:response data:data];
            break;

        case 400:
            [self completeWithError:[self errorWithCode:AMAHostExchangeRequestProcessorBadRequest]];
            break;

        default:
            [self retryIfPossibleOrCompleteWithError:[self networkError]];
            break;
    }
}

- (void)httpRequestor:(AMAHTTPRequestor *)requestor didFinishWithError:(NSError *)error response:(NSHTTPURLResponse *)response
{
    NSError *internalError = [AMAErrorUtilities errorByAddingUnderlyingError:error toError:[self networkError]];
    [self retryIfPossibleOrCompleteWithError:internalError];
}

@end
