#import "AMAAdServicesReportingController.h"
#import "AMAAdServicesDataProvider.h"
#import "AMAAppMetrica+Internal.h"
#import "AMAAttributionModelParser.h"
#import "AMAInternalEventsReporter.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaInMemoryConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAReporter.h"
#import "AMAReporterStateStorage.h"
#import "AMAStartupParametersConfiguration.h"

static NSTimeInterval const kAMAASADefaultDelay = 43200.0;
static NSTimeInterval const kAMAASADefaultInterval = 43200.0;
static NSTimeInterval const kAMAASADefaultEndInterval = 604800.0;

@interface AMAAdServicesReportingController ()

@property (nonatomic, strong, readonly) NSString *apiKey;
@property (nonatomic, strong, readonly) AMAReporterStateStorage *reporterStorage;
@property (nonatomic, strong, readonly) AMAAdServicesDataProvider *dataProvider;
@property (nonatomic, strong, readonly) AMAMetricaConfiguration *configuration;

@end

@implementation AMAAdServicesReportingController

- (instancetype)initWithApiKey:(NSString *)apiKey
               reporterStorage:(AMAReporterStateStorage *)reporterStorage
                 configuration:(AMAMetricaConfiguration *)configuration
                  dataProvider:(AMAAdServicesDataProvider *)dataProvider
{
    self = [super init];
    if (self != nil) {
        _apiKey = apiKey;
        _reporterStorage = reporterStorage;
        _dataProvider = dataProvider;
        _configuration = configuration;
    }

    return self;
}

- (instancetype)initWithApiKey:(NSString *)key reporterStateStorage:(AMAReporterStateStorage *)storage
{
    return [self initWithApiKey:key
                reporterStorage:storage
                  configuration:[AMAMetricaConfiguration sharedInstance]
                   dataProvider:[[AMAAdServicesDataProvider alloc] init]];
}

#pragma mark - Public -

- (void)reportTokenIfNeeded
{
    if (self.executionCondition.shouldExecute) {
        NSError *error = nil;
        NSString *token = [self.dataProvider tokenWithError:&error];
        
        if (token != nil) {
            AMAReporter *reporter = (AMAReporter *)[AMAAppMetrica reporterForAPIKey:self.apiKey];
            [reporter reportASATokenEventWithParameters:@{ @"asaToken" : token } onFailure:nil];
            [[AMAAppMetrica sharedInternalEventsReporter] reportSearchAdsTokenSuccess];
            [self.reporterStorage markASATokenSentNow];
        }
//        else if (error != nil) { //TODO: (Crashes) handle error
//            [sdkReporter reportNSError:error onFailure:nil];
//        }
    }
}

#pragma mark - Private -

- (id<AMAExecutionCondition>)executionCondition
{
    NSNumber *startupDelay = self.configuration.startup.ASATokenFirstDelay;
    NSNumber *startupInterval = self.configuration.startup.ASATokenReportingInterval;
    NSNumber *startupEnd = self.configuration.startup.ASATokenEndReportingInterval;

    NSTimeInterval delay = kAMAASADefaultDelay;
    NSTimeInterval interval = kAMAASADefaultInterval;
    NSTimeInterval endInterval = kAMAASADefaultEndInterval;

    if (startupDelay != nil) {
        delay = startupDelay.doubleValue;
    }
    if (startupInterval != nil) {
        interval = startupInterval.doubleValue;
    }
    if (startupEnd != nil) {
        endInterval = startupEnd.doubleValue;
    }

    NSDate *lastExecutionDate = self.reporterStorage.lastASATokenSendDate;

    id endCondition =
        [[AMAGapExecutionCondition alloc] initWithFirstStartupUpdate:self.configuration.persistent.firstStartupUpdateDate
                                                   lastStartupUpdate:self.configuration.persistent.startupUpdatedAt
                                                lastServerTimeOffset:self.configuration.startup.serverTimeOffset
                                                                 gap:endInterval
                                                 underlyingCondition:nil];
    
    id firstCondition = [[AMAFirstExecutionCondition alloc] initWithFirstStartupUpdate:self.configuration.persistent.firstStartupUpdateDate
                                                                     lastStartupUpdate:self.configuration.persistent.startupUpdatedAt
                                                                          lastExecuted:nil
                                                                  lastServerTimeOffset:self.configuration.startup.serverTimeOffset
                                                                                 delay:delay
                                                                   underlyingCondition:endCondition];
    
    id condition = [[AMAIntervalExecutionCondition alloc] initWithLastExecuted:lastExecutionDate
                                                                      interval:interval
                                                           underlyingCondition:firstCondition];

    return condition;
}

@end
