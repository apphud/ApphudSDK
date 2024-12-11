
#import "AMACore.h"
#import "AMADispatchingController.h"
#import "AMAReporterStorage.h"
#import "AMADispatcher.h"
#import "AMADispatcherDelegate.h"
#import "AMATimeoutRequestsController.h"
#import "AMAUniquePriorityQueue.h"

@interface AMADispatchingController () <AMADispatcherDelegate>

@property (nonatomic, strong, readonly) AMATimeoutRequestsController *reportTimeoutController;
@property (nonatomic, strong, readonly) AMATimeoutRequestsController *trackingTimeoutController;

@property (nonatomic, strong, readonly) NSObject *dispatcherLock;
@property (nonatomic, strong, readonly) NSMutableDictionary<NSString *, AMADispatcher *> *dispatchers;

@property (nonatomic, strong, readonly) NSObject *queueLock;
@property (nonatomic, strong, readonly) AMAUniquePriorityQueue *priorityQueue;

@property (nonatomic, assign) BOOL isWorking;
@property (nonatomic, assign) BOOL started;

@end

@implementation AMADispatchingController

- (instancetype)initWithTimeoutConfiguration:(AMAPersistentTimeoutConfiguration *)timeoutConfiguration
{
    self = [super init];
    if (self != nil) {
        _reportTimeoutController = [[AMATimeoutRequestsController alloc] initWithHostType:AMAReportHostType
                                                                            configuration:timeoutConfiguration];
        _trackingTimeoutController = [[AMATimeoutRequestsController alloc] initWithHostType:AMATrackingHostType
                                                                              configuration:timeoutConfiguration];

        _dispatcherLock = [NSObject new];
        _dispatchers = [NSMutableDictionary dictionary];

        _queueLock = [NSObject new];
        _priorityQueue = [[AMAUniquePriorityQueue alloc] init];

        _started = NO;
        _isWorking = NO;
    }
    return self;
}

#pragma mark - Public -

- (void)registerDispatcherWithReporterStorage:(AMAReporterStorage *)reporterStorage main:(BOOL)main
{
    AMADispatcher *dispatcher = [[AMADispatcher alloc] initWithReporterStorage:reporterStorage
                                                                          main:main
                                                       reportTimeoutController:self.reportTimeoutController
                                                     trackingTimeoutController:self.trackingTimeoutController];
    dispatcher.delegate = self;
    @synchronized (self.dispatcherLock) {
        self.dispatchers[reporterStorage.apiKey] = dispatcher;
    }
}

- (void)performReportForApiKey:(NSString *)apiKey forced:(BOOL)forced
{
    @synchronized (self.queueLock) {
        [self.priorityQueue push:apiKey prioritized:forced];
    }
    BOOL isReportingNeeded = NO;
    @synchronized (self) {
        AMALogInfo(@"Try to report to %@. Is forced: %d. Is working: %d", apiKey, forced, self.isWorking);
        if (self.isWorking == NO) {
            self.isWorking = YES;
            isReportingNeeded = YES;
        }
    }
    if (isReportingNeeded) {
        [self performNextReport];
    }
}

- (void)start
{
    @synchronized (self) {
        self.started = YES;
    }
}

- (void)shutdown
{
    BOOL isCancelingNeeded = NO;
    @synchronized (self) {
        if (self.started) {
            self.started = NO;
            isCancelingNeeded = YES;
        }
    }

    if (isCancelingNeeded) {
        NSArray *dispatchers = nil;
        @synchronized (self.dispatcherLock) {
            dispatchers = self.dispatchers.allValues;
        }
        for (AMADispatcher *dispatcher in dispatchers) {
            [dispatcher cancelPending];
        }
    }
}

#pragma mark - Private -

- (void)performNextReport
{
    AMADispatcher *dispatcher = nil;
    BOOL isForced = NO;
    NSString *apiKey = nil;

    @synchronized (self.queueLock) {
        NSUInteger count = 0;
        while (dispatcher == nil && count < self.priorityQueue.count) {
            apiKey = [self.priorityQueue popPrioritized:&isForced];

            @synchronized (self.dispatcherLock) {
                dispatcher = self.dispatchers[apiKey];
            }

            if (dispatcher == nil) {
                [self.priorityQueue push:apiKey prioritized:isForced];
                AMALogAssert(@"Dispatcher was not found for api-key: %@", apiKey);
            }
            count++;
        }
    }

    BOOL isAllowed = NO;
    @synchronized (self) {
        isAllowed = (isForced || self.started) && dispatcher != nil;
    }
    AMALogInfo(@"Will perform report: %d", isAllowed);
    if (isAllowed) {
        [dispatcher performReport];
    }
    else {
        @synchronized (self) {
            self.isWorking = NO;
        }
    }
}

#pragma mark - AMADispatcherDelegate -

- (void)dispatcherDidPerformReport:(AMADispatcher *)dispatcher
{
    [self.proxyDelegate dispatcherDidPerformReport:dispatcher];
    [self performNextReport];
}

- (void)dispatcher:(AMADispatcher *)dispatcher didFailToReportWithError:(NSError *)error
{
    [self.proxyDelegate dispatcher:dispatcher didFailToReportWithError:error];
    [self performNextReport];
}

- (void)dispatcherWillFinishDispatching:(AMADispatcher *)dispatcher
{
    if ([self.proxyDelegate respondsToSelector:@selector(dispatcherWillFinishDispatching:)]) {
        [self.proxyDelegate dispatcherWillFinishDispatching:dispatcher];
    }
    [self performNextReport];
}

@end
