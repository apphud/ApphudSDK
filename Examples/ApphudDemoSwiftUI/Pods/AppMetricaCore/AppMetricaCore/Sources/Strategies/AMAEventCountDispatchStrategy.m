
#import "AMACore.h"
#import "AMAEventCountDispatchStrategy.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaInMemoryConfiguration.h"
#import "AMAReporterStorage.h"
#import "AMAEventStorage.h"
#import "AMAEventTypes.h"
#import "AMAReporterNotifications.h"

@interface AMAEventCountDispatchStrategy ()

@property (nonatomic, assign) NSUInteger currentCount;
@property (nonatomic, assign) NSUInteger maxCount;
@property (nonatomic, assign, getter = isDispatchScheduled) BOOL dispatchScheduled;
@property (nonatomic, strong) id<AMADelayedExecuting> executor;

@end

@implementation AMAEventCountDispatchStrategy

- (instancetype)initWithDelegate:(id<AMADispatchStrategyDelegate>)delegate
                         storage:(AMAReporterStorage *)storage
       executionConditionChecker:(id<AMAReportExecutionConditionChecker>)executionConditionChecker
{
    return [self initWithDelegate:delegate storage:storage executor:nil executionConditionChecker:executionConditionChecker];
}

- (instancetype)initWithDelegate:(id<AMADispatchStrategyDelegate>)delegate
                         storage:(AMAReporterStorage *)storage
                        executor:(id<AMADelayedExecuting>)executor
       executionConditionChecker:(id<AMAReportExecutionConditionChecker>)executionConditionChecker
{
    self = [super initWithDelegate:delegate storage:storage executionConditionChecker:executionConditionChecker];
    if (self != nil) {
        if (executor == nil) {
            executor = [[AMADelayedExecutor alloc] initWithIdentifier:self];
        }
        _executor = executor;
    }

    return self;
}

- (void)dealloc
{
    [self unsubscribeForNotifications];
}

#pragma mark - Public -

- (void)start
{
    __typeof(self) __weak weakSelf = self;
    [self.executor execute:^{
        __typeof(self) strongSelf = weakSelf;
        if (strongSelf != nil) {
            strongSelf.maxCount = [strongSelf eventsNumberNeededForDispatch];
            [strongSelf subscribeForNotifications];
            [strongSelf triggerDispatchWithUpdatedCount];
        }
    }];
}

- (void)shutdown
{
    [self unsubscribeForNotifications];
}

#pragma mark method for overloading to customise class

- (NSArray *)includedEventTypes
{
    return nil;
}

- (NSArray *)excludedEventTypes
{
    return @[
        @(AMAEventTypeCleanup),
    ];
}

- (NSUInteger)eventsNumberNeededForDispatch
{
    AMAReporterConfiguration *configuration =
        [[AMAMetricaConfiguration sharedInstance] configurationForApiKey:self.storage.apiKey];
    NSUInteger count = configuration.maxReportsCount;
    NSUInteger size = [AMAMetricaConfiguration sharedInstance].inMemory.batchSize;
    count = MIN(count, size);
    return count;
}

#pragma mark - Private -

- (NSUInteger)currentEventsCount
{
    return [self.storage.eventStorage totalCountOfEventsWithTypes:[self includedEventTypes]
                                                   excludingTypes:[self excludedEventTypes]];
}

- (void)executeDelayed:(dispatch_block_t)block
{
    [self.executor executeAfterDelay:0.5 block:block];
}

- (void)triggerDispatchIfNeeded
{
    if ([self isCountReached]) {
        [self triggerDispatch];
    }
}

- (void)triggerDispatchWithUpdatedCount
{
    if (self.maxCount > 0 && self.isDispatchScheduled == NO) {
        self.currentCount = [self currentEventsCount];
        [self triggerDispatchIfNeeded];
    }
}

- (BOOL)isCountReached
{
    NSUInteger maxCount = self.maxCount;
    return (self.currentCount >= maxCount && maxCount > 0);
}

#pragma mark - Working with Notifications

- (void)subscribeForNotifications
{
    if (self.maxCount > 0) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc addObserver:self
               selector:@selector(handleSessionDidAddEventNotification:)
                   name:kAMAReporterDidAddEventNotification
                 object:nil];
    }
}

- (void)unsubscribeForNotifications
{
    if (self.maxCount > 0) {
        NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
        [nc removeObserver:self
                      name:kAMAReporterDidAddEventNotification
                    object:nil];
    }
}

- (BOOL)isCurrentApiKey:(NSString *)apiKey
{
    return [self.storage.apiKey isEqual:apiKey];
}

- (BOOL)eventTypeMatches:(NSNumber *)eventType
{
    NSArray *excludedTypes = [self excludedEventTypes];
    if (excludedTypes != nil && [excludedTypes containsObject:eventType]) {
        return NO;
    }

    NSArray *includedTypes = [self includedEventTypes];
    if (includedTypes == nil) {
        return YES;
    }
    return [includedTypes containsObject:eventType];
}

- (void)updateEventsCount
{
    ++self.currentCount;
    if (self.isDispatchScheduled == NO) {
        self.dispatchScheduled = YES;
        __typeof(self) __weak weakSelf = self;
        [self executeDelayed:^{
            __typeof(self) strongSelf = weakSelf;
            if (strongSelf != nil) {
                strongSelf.dispatchScheduled = NO;
                [strongSelf triggerDispatchIfNeeded];
            }
        }];
    }
}

- (void)handleSessionDidAddEventNotification:(NSNotification *)notif
{
    NSString *apiKey = [notif.userInfo[kAMAReporterDidAddEventNotificationUserInfoKeyApiKey] copy];
    NSNumber *type = notif.userInfo[kAMAReporterDidAddEventNotificationUserInfoKeyEventType];
    __typeof(self) __weak weakSelf = self;
    [self.executor execute:^{
        __typeof(self) strongSelf = weakSelf;
        if (strongSelf != nil) {
            if ([strongSelf isCurrentApiKey:apiKey] && [strongSelf eventTypeMatches:type]) {
                [strongSelf updateEventsCount];
            }
        }
    }];
}

@end
