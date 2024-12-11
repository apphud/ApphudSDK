
#import "AMAAttributionController.h"
#import "AMAAttributionModelConfiguration.h"
#import "AMAReporter.h"
#import "AMAAttributionChecker.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"

@interface AMAAttributionController ()

@property (nonatomic, assign, readwrite) BOOL inited;

@end

@implementation AMAAttributionController

+ (instancetype)sharedInstance
{
    static dispatch_once_t pred;
    static AMAAttributionController *shared = nil;
    dispatch_once(&pred, ^{
        shared = [[self alloc] init];
    });
    return shared;
}

- (instancetype)init
{
    return [self initWithConfig:[AMAMetricaConfiguration sharedInstance].persistent.attributionModelConfiguration];
}

- (instancetype)initWithConfig:(AMAAttributionModelConfiguration *)config
{
    self = [super init];
    if (self != nil) {
        _config = config;
    }
    return self;
}

#pragma mark - Public -

- (void)setMainReporter:(AMAReporter *)mainReporter
{
    @synchronized (self) {
        _mainReporter = mainReporter;
        AMALogInfo(@"config: %@, inited: %d", self.config, self.inited);
        [self maybeSetUpEventsSurveillanceWithReporter:mainReporter config:self.config];
    }
}

- (void)setConfig:(AMAAttributionModelConfiguration *)config
{
    @synchronized (self) {
        _config = config;
        AMALogInfo(@"reporter: %@, config: %@, inited: %d", self.mainReporter, config, self.inited);
        if (self.mainReporter != nil) {
            [self maybeSetUpEventsSurveillanceWithReporter:self.mainReporter config:config];
        }
    }
}

#pragma mark - Private -

- (void)maybeSetUpEventsSurveillanceWithReporter:(AMAReporter *)reporter
                                          config:(AMAAttributionModelConfiguration *)config
{
    if (self.inited) {
        AMALogInfo(@"Already inited");
        return;
    }
    if (config == nil) {
        if ([AMAMetricaConfiguration sharedInstance].persistent.hadFirstStartup) {
            AMALogInfo(@"Set initial attribution checked");
            [AMAMetricaConfiguration sharedInstance].persistent.checkedInitialAttribution = YES;
        }
        AMALogInfo(@"No config");
        return;
    }
    if (@available(iOS 14.0, *)) {
        NSDate *registerForAttributionTime = [AMAMetricaConfiguration sharedInstance].persistent.registerForAttributionTime;
        AMAIntervalExecutionCondition *condition = [[AMAIntervalExecutionCondition alloc]
            initWithLastExecuted:registerForAttributionTime
                        interval:[AMATimeUtilities intervalWithNumber:config.stopSendingTimeSeconds defaultInterval:0]
             underlyingCondition:nil
        ];
        BOOL shouldExecute = condition.shouldExecute == NO;
        AMALogInfo(@"should execute? %d", shouldExecute);
        if (shouldExecute) {
            reporter.attributionChecker = [[AMAAttributionChecker alloc] initWithConfig:config reporter:reporter];
        }
    }
    self.inited = YES;
}

@end
