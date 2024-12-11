
#import "AMACore.h"
#import "AMATimeoutRequestsController.h"
#import "AMATimeoutConfiguration.h"
#import "AMAMetricaConfiguration.h"
#import "AMAStartupParametersConfiguration.h"

static NSUInteger const kAMADefaultMaxTimeout = 600;
static NSUInteger const kAMADefaultMultiplier = 1;

@interface AMATimeoutRequestsController ()

@property (nonatomic, strong, readonly) AMAHostType hostType;
@property (nonatomic, strong, readonly) id<AMADateProviding> dateProvider;

@end

@implementation AMATimeoutRequestsController

- (instancetype)initWithHostType:(AMAHostType)hostType configuration:(AMAPersistentTimeoutConfiguration *)configuration
{
    id<AMADateProviding> dateProvider = [[AMADateProvider alloc] init];
    return [self initWithHostType:hostType configuration:configuration dateProvider:dateProvider];
}

- (instancetype)initWithHostType:(AMAHostType)hostType
                   configuration:(AMAPersistentTimeoutConfiguration *)configuration
                    dateProvider:(id<AMADateProviding>)dateProvider
{
    self = [super init];
    if (self != nil) {
        _hostType = hostType;
        _configuration = configuration;
        _dateProvider = dateProvider;
    }
    return self;
}

#pragma mark - Public -

- (BOOL)isAllowed
{
    AMATimeoutConfiguration *config = [self.configuration timeoutConfigForHostType:self.hostType];
    if (config.limitDate != nil) {
        NSTimeInterval interval = [config.limitDate timeIntervalSinceDate:self.dateProvider.currentDate];
        if (interval > 0) {
            AMALogError(@"Denying report for `%@`. Backoff: %f", self.hostType, interval);
            return NO;
        }
    }
    AMALogInfo(@"Allowing report for `%@`", self.hostType);
    return YES;
}

- (void)reportOfSuccess
{
    AMATimeoutConfiguration *config = [self.configuration timeoutConfigForHostType:self.hostType];
    config.count = 0;
    config.limitDate = nil;
    
    AMALogInfo(@"Reporting success for `%@`", self.hostType);
    
    [self.configuration saveTimeoutConfig:config forHostType:self.hostType];
}

- (void)reportOfFailure
{
    AMATimeoutConfiguration *config = [self.configuration timeoutConfigForHostType:self.hostType];
    config = config ?: [[AMATimeoutConfiguration alloc] initWithLimitDate:[self.dateProvider currentDate] count:0];
    NSTimeInterval interval = [self intervalForAttempt:++config.count];
    config.limitDate = [self.dateProvider.currentDate dateByAddingTimeInterval:interval];
    
    AMALogError(@"Report failed for `%@`. Backoff interval: %f, count: %tu",
                        self.hostType, interval, config.count);
    
    [self.configuration saveTimeoutConfig:config forHostType:self.hostType];
}

#pragma mark - Private -

- (NSTimeInterval)intervalForAttempt:(NSUInteger)attempt
{
    AMAStartupParametersConfiguration *configuration = [AMAMetricaConfiguration sharedInstance].startup;

    NSNumber *multiplierNumber = configuration.retryPolicyExponentialMultiplier;
    NSNumber *maxNumber = configuration.retryPolicyMaxIntervalSeconds;

    NSUInteger multiplier = multiplierNumber == nil ? kAMADefaultMultiplier : [multiplierNumber unsignedIntegerValue];
    NSUInteger max = maxNumber == nil ? kAMADefaultMaxTimeout : [maxNumber unsignedIntegerValue];

    NSUInteger seconds = ((1 << attempt) - 1) * multiplier;

    return seconds > max ? max : seconds;
}

@end
