
#import "AMACore.h"
#import "AMALocationDispatchStrategy.h"
#import "AMALocationStorage.h"
#import "AMALocationCollectingConfiguration.h"
#import "AMADataSendingRestrictionController.h"

static NSTimeInterval const kAMADelayAfterFailedRequest = 10.0;

@interface AMALocationDispatchStrategy ()

@property (nonatomic, strong, readonly) AMALocationStorage *storage;
@property (nonatomic, strong, readonly) AMALocationCollectingConfiguration *configuration;
@property (nonatomic, strong, readonly) id<AMADateProviding> dateProvider;

@property (nonatomic, strong) NSDate *lastFailedRequestDate;

@end

@implementation AMALocationDispatchStrategy

- (instancetype)initWithStorage:(AMALocationStorage *)storage
                  configuration:(AMALocationCollectingConfiguration *)configuration
{
    return [self initWithStorage:storage
                   configuration:configuration
                    dateProvider:[[AMADateProvider alloc] init]];
}

- (instancetype)initWithStorage:(AMALocationStorage *)storage
                  configuration:(AMALocationCollectingConfiguration *)configuration
                   dateProvider:(id<AMADateProviding>)dateProvider
{
    self = [super init];
    if (self != nil) {
        _storage = storage;
        _configuration = configuration;
        _dateProvider = dateProvider;
        _lastFailedRequestDate = [NSDate distantPast];
    }
    return self;
}

#pragma mark - Public -

- (BOOL)shouldSendLocation
{
    BOOL shouldSend = NO;
    if ([[AMADataSendingRestrictionController sharedInstance] shouldEnableLocationSending]) {
        id<AMALSSLocationsProviding> state = [self.storage locationStorageState];
        shouldSend = shouldSend || state.locationsCount >= self.configuration.recordsCountToForceFlush;
        shouldSend = shouldSend || [self timeIntervalForNextSendWithState:state] <= 0.0;
    }

    shouldSend = shouldSend && [self failedRequestDelayPassed];
    return shouldSend;
}

- (BOOL)shouldSendVisit
{
    BOOL shouldSend = NO;
    if ([[AMADataSendingRestrictionController sharedInstance] shouldEnableLocationSending]) {
        shouldSend = [self.storage locationStorageState].visitsCount > 0;
    }

    shouldSend = shouldSend && [self failedRequestDelayPassed];
    return shouldSend;
}

- (void)handleRequestFailure
{
    self.lastFailedRequestDate = self.dateProvider.currentDate;
}

#pragma mark - Private -

- (NSTimeInterval)timeIntervalForNextSendWithState:(id<AMALSSLocationsProviding>)state
{
    if (state.firstLocationDate == nil) {
        return DBL_MAX;
    }
    NSDate *now = self.dateProvider.currentDate;
    return self.configuration.maxAgeToForceFlush - [now timeIntervalSinceDate:state.firstLocationDate];
}

- (BOOL)failedRequestDelayPassed
{
    NSTimeInterval timeSinceLastFailedRequest =
        [self.dateProvider.currentDate timeIntervalSinceDate:self.lastFailedRequestDate];
    return timeSinceLastFailedRequest >= kAMADelayAfterFailedRequest;
}

@end
