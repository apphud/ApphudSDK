
#import "AMACore.h"
#import "AMALocationDispatcher.h"
#import "AMALocationDispatchStrategy.h"
#import "AMALocationCollectingConfiguration.h"
#import "AMALocationStorage.h"
#import "AMALocationRequestProvider.h"
#import "AMALocationRequest.h"
#import "AMAErrorsFactory.h"
#import "AMATimeoutRequestsController.h"

static NSTimeInterval const kAMATimerTriggerInterval = 60.0;

@interface AMALocationDispatcher ()

@property (nonatomic, strong, readonly) AMALocationStorage *storage;
@property (nonatomic, strong, readonly) AMALocationCollectingConfiguration *configuration;
@property (nonatomic, strong, readonly) AMALocationDispatchStrategy *strategy;
@property (nonatomic, strong, readonly) AMALocationRequestProvider *requestProvider;
@property (nonatomic, strong, readonly) AMAReportResponseParser *responseParser;
@property (nonatomic, strong, readonly) AMATimeoutRequestsController *timeoutController;
@property (nonatomic, strong, readonly) id<AMACancelableExecuting> executor;

@property (nonatomic, strong) AMAHostExchangeRequestProcessor *currentProcessor;
@property (nonatomic, assign) BOOL timerScheduled;

@end

@implementation AMALocationDispatcher

- (instancetype)initWithStorage:(AMALocationStorage *)storage
                  configurtaion:(AMALocationCollectingConfiguration *)configuration
                       executor:(id<AMACancelableExecuting>)executor
              timeoutController:(AMATimeoutRequestsController *)timeoutController
{
    return [self
        initWithStorage:storage
          configurtaion:configuration
               executor:executor
               strategy:[[AMALocationDispatchStrategy alloc] initWithStorage:storage configuration:configuration]
        requestProvider:[[AMALocationRequestProvider alloc] initWithStorage:storage configuration:configuration]
         responseParser:[[AMAReportResponseParser alloc] init]
      timeoutController:timeoutController];
}

- (instancetype)initWithStorage:(AMALocationStorage *)storage
                  configurtaion:(AMALocationCollectingConfiguration *)configuration
                       executor:(id<AMACancelableExecuting>)executor
                       strategy:(AMALocationDispatchStrategy *)strategy
                requestProvider:(AMALocationRequestProvider *)requestProvider
                 responseParser:(AMAReportResponseParser *)responseParser
              timeoutController:(AMATimeoutRequestsController *)timeoutController
{
    self = [super init];
    if (self != nil) {
        _storage = storage;
        _configuration = configuration;
        _strategy = strategy;
        _requestProvider = requestProvider;
        _responseParser = responseParser;
        _executor = executor;
        _timeoutController = timeoutController;
    }
    return self;
}

#pragma mark - Public -

- (void)handleLocationAdd
{
    [self triggerLocationSend];
}

- (void)handleVisitAdd
{
    [self triggerVisitSend];
}

#pragma mark - Private -

- (void)trigger
{
    self.strategy.shouldSendVisit ? [self triggerVisitSend] : [self triggerLocationSend];
}

- (void)triggerLocationSend
{
    if (self.strategy.shouldSendLocation && self.isDispatchingAllowed) {
        [self processRequest:[self.requestProvider nextLocationsRequest]];
    }
    [self scheduleTimer];
}

- (void)triggerVisitSend
{
    if (self.strategy.shouldSendVisit && self.isDispatchingAllowed) {
        [self processRequest:[self.requestProvider nextVisitsRequest]];
    }
    [self scheduleTimer];
}

- (BOOL)isDispatchingAllowed
{
    return self.currentProcessor == nil && self.timeoutController.isAllowed;
}

- (void)scheduleTimer
{
    if (self.timerScheduled) {
        return;
    }

    self.timerScheduled = YES;
    __weak __typeof(self) weakSelf = self;
    [self.executor executeAfterDelay:kAMATimerTriggerInterval block:^{
        __strong __typeof(weakSelf) strongSelf = weakSelf;
        strongSelf.timerScheduled = NO;
        [strongSelf trigger];
    }];
}

- (void)cancelTimer
{
    [self.executor cancelDelayed];
    self.timerScheduled = NO;
}

- (void)processRequest:(AMALocationRequest *)request
{
    AMAArrayIterator *hostsProvider = [[AMAArrayIterator alloc] initWithArray:self.configuration.hosts];

    if (request == nil) {
        NSError *inconsistencyError = [AMAErrorsFactory internalInconsistencyError];
        [self completeWithLocationIdentifiers:nil visitIdentifiers:nil error:inconsistencyError];
        return;
    }
    self.currentProcessor = [[AMAHostExchangeRequestProcessor alloc] initWithRequest:request
                                                                            executor:self.executor
                                                                        hostProvider:hostsProvider
                                                                   responseValidator:self.responseParser];

    NSArray *locationIds = request.locationIdentifiers;
    NSArray *visitIds = request.visitIdentifiers;

    __weak typeof(self) weakSelf = self;
    [self.currentProcessor processWithCallback:^(NSError *error) {
        [weakSelf completeWithLocationIdentifiers:locationIds visitIdentifiers:visitIds error:error];
    }];
}

- (void)completeWithLocationIdentifiers:(NSArray *)locationIdentifiers
                       visitIdentifiers:(NSArray *)visitIdentifiers
                                  error:(NSError *)error
{
    if (error == nil || error.code == AMAHostExchangeRequestProcessorBadRequest) {
        [self.storage incrementRequestIdentifier];
        [self.storage purgeLocationsWithIdentifiers:locationIdentifiers];
        [self.storage purgeVisitsWithIdentifiers:visitIdentifiers];
        [self.timeoutController reportOfSuccess];
    }
    else {
        if (error != nil && error.code == AMAHostExchangeRequestProcessorNetworkError) {
            [self.timeoutController reportOfFailure];
        }
        else {
            [self.strategy handleRequestFailure];
        }
    }

    if (error != nil) {
        AMALogError(@"Failed to report location: %@", error);
    }

    self.currentProcessor = nil;
    [self cancelTimer];
    [self trigger];
}

@end
