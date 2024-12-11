#import "AMACore.h"

#import "AMAExtensionsReportController.h"

#import "AMAAppMetrica+Internal.h"
#import "AMAExtensionReportProvider.h"
#import "AMAExtensionsReportExecutionConditionProvider.h"
#import "AMAInternalEventsReporter.h"

@interface AMAExtensionsReportController ()

@property (nonatomic, strong, readonly) AMAInternalEventsReporter *reporter;
@property (nonatomic, strong, readonly) AMAExtensionsReportExecutionConditionProvider *conditionProvider;
@property (nonatomic, strong, readonly) AMAExtensionReportProvider *reportProvider;
@property (nonatomic, strong, readonly) id<AMADelayedExecuting> executor;

@end

@implementation AMAExtensionsReportController

- (instancetype)init
{
    return [self initWithReporter:[AMAAppMetrica sharedInternalEventsReporter]
                conditionProvider:[[AMAExtensionsReportExecutionConditionProvider alloc] init]
                         provider:[[AMAExtensionReportProvider alloc] init]
                         executor:[[AMADelayedExecutor alloc] initWithIdentifier:self]];
}

- (instancetype)initWithReporter:(AMAInternalEventsReporter *)reporter
               conditionProvider:(AMAExtensionsReportExecutionConditionProvider *)conditionProvider
                        provider:(AMAExtensionReportProvider *)provider
                        executor:(id<AMADelayedExecuting>)executor
{
    self = [super init];
    if (self != nil) {
        _reporter = reporter;
        _conditionProvider = conditionProvider;
        _reportProvider = provider;
        _executor = executor;
    }
    return self;
}

#pragma mark - Public -

- (void)reportIfNeeded
{
    AMALogInfo(@"Trying to report extensions list");
    if ([self conditionPassed]) {
        __weak __typeof(self) weakSelf = self;
        [self.executor executeAfterDelay:self.conditionProvider.launchDelay block:^{
            __strong __typeof(weakSelf) strongSelf = weakSelf;
            if (strongSelf != nil) {
                if ([strongSelf conditionPassed]) {
                    [strongSelf report];
                }
            }
        }];
    }
}

#pragma mark - Private -

- (void)report
{
    NSDictionary *report = nil;
    @try {
        AMALogInfo(@"Collectiong extensions report");
        report = [self.reportProvider report];
    } @catch (NSException *exception) {
        AMALogError(@"Exception during extensions report collecting: %@", exception);
        [self.reporter reportExtensionsReportCollectingException:exception];
    }
    if (report != nil) {
        AMALogInfo(@"Reporting extensions list report");
        [self.reporter reportExtensionsReportWithParameters:report];
    }
    [self.conditionProvider executed];
}

- (BOOL)conditionPassed
{
    BOOL passed = NO;
    if (self.conditionProvider.enabled == NO) {
        AMALogInfo(@"Extensions reporting is disabled");
    }
    else if ([[self.conditionProvider executionCondition] shouldExecute] == NO) {
        AMALogInfo(@"Extensions reporting condition is not satisfied");
    }
    else {
        passed = YES;
    }
    return passed;
}

#pragma mark - AMAStartupCompletionObserving

- (void)startupUpdateCompletedWithConfiguration:(AMAStartupParametersConfiguration *)configuration
{
    [self reportIfNeeded];
}

@end
