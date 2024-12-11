
#import "AMACore.h"
#import "AMAStartupResponseParser.h"
#import "AMAStartupController.h"
#import "AMAStartupRequest.h"
#import "AMAExponentialDelayStrategy.h"
#import "AMAStartupHostProvider.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAStartupParametersConfiguration.h"
#import "AMAErrorsFactory.h"
#import "AMATimeoutRequestsController.h"
#import "AMAUUIDProvider.h"
#import "AMAAttributionController.h"

static NSTimeInterval const kAMAStartupDefaultRequestsInterval = 1 * AMA_DAYS;
NSErrorDomain const AMAStartupRequestsErrorDomain = @"AMAStartupRequestsErrorDomain";

@interface AMAStartupController () <AMAHTTPRequestDelegate>

@property (nonatomic, strong) id<AMACancelableExecuting> executor;
@property (nonatomic, strong) id<AMAResettableIterable> hostProvider;
@property (nonatomic, strong) AMAStartupRequest *startupRequest;
@property (nonatomic, strong) AMAHTTPRequestor *currentHTTPRequestor;
@property (nonatomic, strong, readonly) id<AMADelayStrategy> delayStrategy;
@property (nonatomic, strong, readonly) AMATimeoutRequestsController *timeoutRequestsController;
@property (nonatomic, strong, readonly) AMAStartupResponseParser *startupResponseParser;
@property (nonatomic, strong, readonly) AMAHTTPRequestsFactory *requestsFactory;

@end

@implementation AMAStartupController

@dynamic upToDate;

- (instancetype)initWithTimeoutRequestsController:(AMATimeoutRequestsController *)timeoutRequestsController
{
    id<AMACancelableExecuting> executor = [[AMACancelableDelayedExecutor alloc] initWithIdentifier:self];
    AMAStartupHostProvider *hostProvider = [[AMAStartupHostProvider alloc] init];
    return [self initWithExecutor:executor
                     hostProvider:hostProvider
        timeoutRequestsController:timeoutRequestsController
            startupResponseParser:[[AMAStartupResponseParser alloc] init]];
}

- (instancetype)initWithExecutor:(id<AMACancelableExecuting>)executor
                    hostProvider:(id<AMAResettableIterable>)hostProvider
       timeoutRequestsController:(AMATimeoutRequestsController *)timeoutRequestsController
           startupResponseParser:(AMAStartupResponseParser *)startupResponseParser
{
    self = [super init];
    if (self != nil) {
        _startupRequest = [[AMAStartupRequest alloc] init];
        _delayStrategy = [[AMAExponentialDelayStrategy alloc] init];
        _hostProvider = hostProvider;
        _executor = executor;
        _timeoutRequestsController = timeoutRequestsController;
        _startupResponseParser = startupResponseParser;
        _requestsFactory = [[AMAHTTPRequestsFactory alloc] init];
    }

    return self;
}

#pragma mark - Public -

- (BOOL)upToDate
{
    BOOL isUpToDate = NO;
    AMAMetricaConfiguration *configuration = [AMAMetricaConfiguration sharedInstance];
    NSDate *lastUpdated = configuration.persistent.startupUpdatedAt;
    if (lastUpdated != nil && [self hasIdentifiers]) {
        NSNumber *updateInterval = configuration.startup.startupUpdateInterval ?: @(kAMAStartupDefaultRequestsInterval);
        NSTimeInterval currentUpdateInterval = -[lastUpdated timeIntervalSinceNow];
        isUpToDate = currentUpdateInterval <= updateInterval.doubleValue;
    }
    return isUpToDate;
}

- (void)update
{
    if (self.upToDate == NO && self.currentHTTPRequestor == nil) {
        @synchronized (self) {
            if (self.upToDate == NO && self.currentHTTPRequestor == nil) {
                [self.hostProvider reset];
                [self executeRequest];
            }
        }
    }
}

- (void)cancel
{
    @synchronized (self) {
        [self.currentHTTPRequestor cancel];
        [self.executor cancelDelayed];
        self.currentHTTPRequestor = nil;
    }
}

- (void)addAdditionalStartupParameters:(NSDictionary *)parameters
{
    @synchronized (self) {
        [self.startupRequest addAdditionalStartupParameters:parameters];
    }
}

#pragma mark - Private -

- (void)executeRequest
{
    NSTimeInterval delay = [self.delayStrategy delay];
    [self executeRequestAfterDelay:delay];
}

- (void)executeRequestAfterDelay:(NSTimeInterval)delay
{
    self.startupRequest.host = self.hostProvider.current;
    AMAHTTPRequestor *httpRequestor = [self.requestsFactory requestorForRequest:self.startupRequest];
    httpRequestor.delegate = self;
    httpRequestor.delegateExecutor = self.executor;
    self.currentHTTPRequestor = httpRequestor;

    __weak __typeof(self) weakSelf = self;
    [self.executor executeAfterDelay:delay block:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        if (strongSelf != nil) {
            @synchronized (strongSelf) {
                if (httpRequestor == strongSelf.currentHTTPRequestor) {
                    if ([self.timeoutRequestsController isAllowed]) {
                        [httpRequestor start];
                    }
                    else {
                        [self reportOfTimeoutWithRequest:httpRequestor];
                    }
                }
            }
        }
    }];
}

- (BOOL)hasIdentifiers
{
    return [AMAUUIDProvider sharedInstance].retrieveUUID != nil &&
        [AMAMetricaConfiguration sharedInstance].persistent.deviceIDHash != nil;
}

- (AMAStartupResponse *)parseResponse:(NSHTTPURLResponse *)response data:(NSData *)data
{
    NSError *__autoreleasing error = nil;
    AMAStartupResponse *sr = [self.startupResponseParser startupResponseWithHTTPResponse:response
                                                                                    data:data
                                                                                   error:&error];
    if (sr == nil) {
        AMALogError(@"Failed to parse response with error: %@", error);
    }
    return sr;
}

- (NSDictionary *)parseExtendedResponse:(NSHTTPURLResponse *)response data:(NSData *)data
{
    NSError *__autoreleasing error = nil;
    NSDictionary *result = [self.startupResponseParser extendedStartupResponseWithHTTPResponse:response
                                                                                          data:data
                                                                                         error:&error];
    if (result == nil) {
        AMALogInfo(@"Failed to parse extended response with error: %@", error);
    }
    return result;
}

- (void)handleStartupResponse:(AMAStartupResponse *)startupResponse
{
    AMALogInfo(@"Handle startup response %@", startupResponse);
    AMAMetricaConfiguration *configuration = [AMAMetricaConfiguration sharedInstance];
    AMAMetricaPersistentConfiguration *persistent = configuration.persistent;

    if (startupResponse.deviceID.length > 0) {
        persistent.deviceID = startupResponse.deviceID;
    }
    if (startupResponse.deviceIDHash.length > 0) {
        persistent.deviceIDHash = startupResponse.deviceIDHash;
    }
    if (persistent.hadFirstStartup == NO) {
        persistent.attributionModelConfiguration = startupResponse.attributionModelConfiguration;
    }

    [configuration updateStartupConfiguration:startupResponse.configuration];

    persistent.hadFirstStartup = YES;
    if (persistent.firstStartupUpdateDate == nil && startupResponse.configuration.serverTimeOffset != nil) {
        NSTimeInterval serverTimeOffset = [startupResponse.configuration.serverTimeOffset doubleValue];
        persistent.firstStartupUpdateDate = [NSDate dateWithTimeIntervalSinceNow:serverTimeOffset];
    }

    persistent.startupUpdatedAt = [NSDate date];
    [AMAAttributionController sharedInstance].config = persistent.attributionModelConfiguration;
}

#pragma mark - Errors

- (void)reportOfTimeoutWithRequest:(AMAHTTPRequestor *)request
{
    NSError *error = [[NSError alloc] initWithDomain:AMAStartupRequestsErrorDomain
                                                code:AMAStartupRequestsErrorTimeout
                                            userInfo:nil];
    [self reportErrorWithRequest:request error:error];
}

- (void)reportErrorWithRequest:(AMAHTTPRequestor *)request error:(NSError *)error
{
    BOOL reportError = NO;

    if (self.currentHTTPRequestor == request) {
        @synchronized (self) {
            if (self.currentHTTPRequestor == request) {
                BOOL isTimeoutError = [error.domain isEqualToString:AMAStartupRequestsErrorDomain] &&
                                      error.code == AMAStartupRequestsErrorTimeout;

                if (isTimeoutError) {
                    reportError = YES;
                }
                else {
                    if (error.code == NSURLErrorNotConnectedToInternet) {
                        reportError = YES;
                    }
                    else {
                        reportError = [self.hostProvider next] == nil;
                        if (reportError) {
                            [self.timeoutRequestsController reportOfFailure];
                        }
                    }
                }

                if (reportError) {
                    [self cancel];
                }
                else {
                    [self executeRequestAfterDelay:0.0];
                }
            }
        }
    }

    if (reportError) {
        [self.delegate startupController:self didFailWithError:error];
    }
}

#pragma mark - AMAHTTPRequestDelegate

- (void)httpRequestor:(AMAHTTPRequestor *)requestor
   didFinishWithError:(NSError *)error
             response:(NSHTTPURLResponse *)response
{
    [self reportErrorWithRequest:requestor error:error];
}

- (void)httpRequestor:(AMAHTTPRequestor *)requestor
    didFinishWithData:(NSData *)data
             response:(NSHTTPURLResponse *)response
{
    BOOL canAcceptResponse = NO;
    AMAStartupResponse *startupResponse = nil;
    NSDictionary *extendedStartupResponse = nil;

    if (self.currentHTTPRequestor == requestor) {
        if (response.statusCode == 200) {
            [self.timeoutRequestsController reportOfSuccess];
            startupResponse = [self parseResponse:response data:data];
            extendedStartupResponse = [self parseExtendedResponse:response data:data];
        }

        if (startupResponse == nil) {
            [self httpRequestor:requestor didFinishWithError:[AMAErrorsFactory badServerResponseError] response:response];
        }
        else {
            @synchronized (self) {
                if (self.currentHTTPRequestor == requestor) {
                    canAcceptResponse = YES;
                    [self handleStartupResponse:startupResponse];
                    [self cancel];
                }
            }
        }
    }

    if (canAcceptResponse) {
        [[AMAMetricaConfiguration sharedInstance] synchronizeStartup];

        [self.delegate startupControllerDidFinishWithSuccess:self];
        [self.extendedDelegate startupUpdatedWithResponse:extendedStartupResponse];
    }
}

@end
