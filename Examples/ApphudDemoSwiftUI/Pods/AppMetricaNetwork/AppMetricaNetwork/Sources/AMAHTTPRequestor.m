
#import "AMANetworkCore.h"
#import <AppMetricaNetwork/AppMetricaNetwork.h>

@interface AMAHTTPRequestor ()

@property (nonatomic, strong, readonly) id<AMANetworkSessionProviding> sessionProvider;

@property (nonatomic, strong) NSURLSessionDataTask *currentTask;
@property (nonatomic, assign) BOOL cancelled;

@end

@implementation AMAHTTPRequestor

+ (instancetype)requestorWithRequest:(id<AMARequest>)request
{
    return [[self alloc] initWithRequest:request];
}

- (instancetype)initWithRequest:(id<AMARequest>)request
{
    id<AMANetworkSessionProviding> sessionProvider = [AMANetworkStrategyController sharedInstance].sessionProvider;
    return [self initWithRequest:request
                 sessionProvider:sessionProvider];
}

- (instancetype)initWithRequest:(id<AMARequest>)request
                sessionProvider:(id<AMANetworkSessionProviding>)sessionProvider
{
    if (request == nil) {
        AMALogAssert(@"Request can't be nil");
        return nil;
    }

    self = [super init];
    if (self != nil) {
        _request = request;
        _sessionProvider = sessionProvider;
    }
    return self;
}

- (void)start
{
    @synchronized (self) {
        if (self.currentTask != nil) {
            AMALogAssert(@"Request can't be started more than once");
        }
        else if (self.cancelled) {
            AMALogAssert(@"Can't start cancelled request");
        }
        else {
            NSURLSession *session = self.sessionProvider.session;
            NSURLRequest *urlRequest = [self.request buildURLRequest];
            if (urlRequest != nil) {
                NSURLSessionDataTask *task = [session dataTaskWithRequest:urlRequest
                                                        completionHandler:[self completionHandler]];
                AMALogInfo(@"Start request[size: %lu]: %@",
                           (unsigned long)self.request.body.length, self.request);
                [task resume];
                self.currentTask = task;
            }
            else {
                AMALogAssert(@"Invalid URL request");
            }
        }
    }
}

- (void (^)(NSData *, NSURLResponse *, NSError *))completionHandler
{
    __weak __typeof(self) weakSelf = self;
    return ^(NSData *data, NSURLResponse *response, NSError *error) {
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        AMALogInfo(@"Request: %@", strongSelf.request);
        dispatch_block_t block = ^{
            [weakSelf taskDidCompleteWithData:data response:response error:error];
        };

        if (strongSelf.delegateExecutor == nil) {
            block();
        }
        else {
            [strongSelf.delegateExecutor execute:block];
        }
    };
}

- (void)taskDidCompleteWithData:(NSData *)data response:(NSURLResponse *)response error:(NSError *)error
{
    NSHTTPURLResponse *httpResponse = [self httpUrlResponseFromUrlResponse:response];
    if (httpResponse != nil && error == nil) {
        AMALogInfo(@"Response[status code: %ld; size: %lu]: %@",
                           (long)httpResponse.statusCode,
                           (unsigned long)data.length,
                           httpResponse);
        [self.delegate httpRequestor:self didFinishWithData:data response:httpResponse];
    }
    else {
        AMALogInfo(@"Request error[status code: %ld]: %@", (long)error.code, error.localizedDescription);
        [self.delegate httpRequestor:self didFinishWithError:error response:httpResponse];
    }
}

- (void)cancel
{
    @synchronized (self) {
        AMALogInfo(@"Cancel task: %@", self.request);
        self.cancelled = YES;
        [self.currentTask cancel];
    }
}

- (NSHTTPURLResponse *)httpUrlResponseFromUrlResponse:(NSURLResponse *)urlResponse
{
    NSHTTPURLResponse *httpUrlResponse = nil;
    if (urlResponse != nil && [urlResponse isKindOfClass:[NSHTTPURLResponse class]]) {
        httpUrlResponse = (NSHTTPURLResponse *)urlResponse;
    }

    return httpUrlResponse;
}

@end
