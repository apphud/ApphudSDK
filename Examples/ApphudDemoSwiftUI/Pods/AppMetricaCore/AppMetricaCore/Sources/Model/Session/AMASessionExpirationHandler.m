
#import "AMASessionExpirationHandler.h"
#import "AMADate.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaInMemoryConfiguration.h"
#import "AMAReporterConfiguration.h"
#import "AMASession.h"

static NSTimeInterval const kAMAMinimalValuableTimeUnit = 0.1;

@interface AMASessionExpirationHandler ()

@property (nonatomic, strong) AMAMetricaConfiguration *configuration;
@property (nonatomic, copy) NSString *apiKey;

@end

@implementation AMASessionExpirationHandler

#pragma mark - Public -

- (instancetype)initWithConfiguration:(AMAMetricaConfiguration *)configuration APIKey:(NSString *)apiKey
{
    self = [super init];
    if (self != nil) {
        _configuration = configuration;
        _apiKey = [apiKey copy];
    }
    return self;
}

- (AMASessionExpirationType)expirationTypeForSession:(nullable AMASession *)session
                                            withDate:(NSDate *)date
{
    if (session == nil) {
        return AMASessionExpirationTypeInvalid;
    }
    NSUInteger sessionTimeout = [self retrieveSessionTimeout:session];
    NSUInteger sessionMaxDuration = self.configuration.inMemory.sessionMaxDuration;
    NSDate *sessionStartingDate = session.startDate.deviceDate;
    NSDate *sessionPauseTime = (session.type == AMASessionTypeBackground)
        ? session.lastEventTime ?: sessionStartingDate
        : session.pauseTime;
    
    NSTimeInterval timeSinceSessionStart = [date timeIntervalSinceDate:sessionStartingDate];
    NSTimeInterval timeSinceSessionPause = [date timeIntervalSinceDate:sessionPauseTime];
    
    BOOL sessionStartedInFuture = timeSinceSessionStart < -kAMAMinimalValuableTimeUnit;
    BOOL sessionExceedsMaxDuration = timeSinceSessionStart > sessionMaxDuration;
    BOOL sessionExceedsTimeout = timeSinceSessionPause > sessionTimeout;
    
    if (sessionStartedInFuture) {
        return AMASessionExpirationTypePastDate;
    }
    else if (sessionExceedsMaxDuration) {
        return AMASessionExpirationTypeDurationLimit;
    }
    else if (sessionExceedsTimeout) {
        return AMASessionExpirationTypeTimeout;
    }
    return AMASessionExpirationTypeNone;
}

#pragma mark - Private -

- (NSUInteger)retrieveSessionTimeout:(AMASession *)session
{
    switch (session.type) {
        case AMASessionTypeGeneral:
            return [self.configuration configurationForApiKey:self.apiKey].sessionTimeout;
        case AMASessionTypeBackground:
            return self.configuration.inMemory.backgroundSessionTimeout;
        default:
            return 0;       
    }
}

@end
