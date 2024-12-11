
#import "AMAInternalEventsReporter.h"
#import "AMAReporter.h"
#import "AMAReporterProviding.h"
#import "AMAEventTypes.h"
#import <AppMetricaHostState/AppMetricaHostState.h>

static NSString *const kAMASchemaInconsistencyEventName = @"SchemaInconsistencyDetected";
static NSString *const kAMASchemaInconsistencyEventParametersDescriptionKey = @"schema: ";

static NSString *const kAMASearchAdsTokenSuccessEventName = @"AppleSearchAdsTokenSuccess";

@interface AMAInternalEventsReporter ()

@property (nonatomic, strong, readonly) id<AMAAsyncExecuting> executor;
@property (nonatomic, strong, readonly) id<AMAReporterProviding> reporterProvider;

@property (nonatomic, strong) id<AMAHostStateProviding> hostStateProvider;

@end

@implementation AMAInternalEventsReporter

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting>)executor
                reporterProvider:(id<AMAReporterProviding>)reporterProvider
{
    return [self initWithExecutor:executor
                 reporterProvider:reporterProvider
                hostStateProvider:[[AMAHostStateProvider alloc] init]];
}

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting>)executor
                reporterProvider:(id<AMAReporterProviding>)reporterProvider
               hostStateProvider:(id<AMAHostStateProviding>)hostStateProvider
{
    self = [super init];
    if (self != nil) {
        _executor = executor;
        _reporterProvider = reporterProvider;
        _hostStateProvider = hostStateProvider;
        _hostStateProvider.delegate = self;
    }
    return self;
}

- (void)reportEvent:(NSString *)event parameters:(NSDictionary *)parameters
{
    [self.executor execute:^{
        id<AMAAppMetricaReporting> reporter = [self.reporterProvider reporter];
        [reporter reportEvent:event parameters:parameters onFailure:nil];
    }];
}

- (void)reportSchemaInconsistencyWithDescription:(NSString *)inconsistencyDescription
{
    NSDictionary *parameters = nil;
    if (inconsistencyDescription != nil) {
        parameters = @{ kAMASchemaInconsistencyEventParametersDescriptionKey : inconsistencyDescription };
    }
    [self reportEvent:kAMASchemaInconsistencyEventName parameters:parameters];
}

- (void)reportSearchAdsTokenSuccess
{
    [self reportEvent:kAMASearchAdsTokenSuccessEventName parameters:nil];
}

- (void)reportExtensionsReportWithParameters:(NSDictionary *)parameters
{
    [self reportEvent:@"extensions_list" parameters:parameters];
}

- (void)reportExtensionsReportCollectingException:(NSException *)exception
{
    NSDictionary *parameters = nil;
    if (exception.name != nil) {
        parameters = @{ exception.name: exception.reason ?: @"Unknown reason" };
    }
    [self reportEvent:@"extensions_list_collecting_exception" parameters:parameters];
}

- (void)reportSKADAttributionParsingError:(NSDictionary *)parameters
{
    [self reportEvent:@"skad_attribution_parsing_error" parameters:parameters];
}

- (void)reportEventFileNotFoundForEventWithType:(NSUInteger)eventType
{
    NSDictionary *parameters = @{ @"event_type": @(eventType) };
    switch (eventType) {
        case AMAEventTypeProtobufCrash:
        case AMAEventTypeProtobufANR:
            // TODO(bamx23): Drop this event?
            [self reportEvent:@"empty_crash" parameters:parameters];
            break;

        default:
            [self reportEvent:@"event_value_file_not_found" parameters:parameters];
            break;
    }
}

#pragma mark - Utils -

- (void)reportEvent:(NSString *)event withError:(NSError *)error
{
    NSDictionary *parameters = @{
        @"domain" : error.domain ?: @"<unknown>",
        @"error_code" : @(error.code),
        @"error_details" : error.userInfo.description ?: @"No error details supplied",
    };
    [self reportEvent:event parameters:parameters];
}

#pragma mark - AMAHostStateProviderDelegate delegate -

- (void)hostStateDidChange:(AMAHostAppState)hostState
{
    AMALogInfo(@"state: %lu", (unsigned long)hostState);
    switch (hostState) {
        case AMAHostAppStateForeground:
            [[self.reporterProvider reporter] resumeSession];
            break;
        case AMAHostAppStateBackground:
            [[self.reporterProvider reporter] pauseSession];
            break;
        default:
            break;
    }
}

@end
