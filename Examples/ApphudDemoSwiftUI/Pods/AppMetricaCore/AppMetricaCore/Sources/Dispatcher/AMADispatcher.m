
#import "AMAEvent.h"
#import "AMAReportsController.h"
#import "AMADispatcher.h"
#import "AMADispatcherDelegate.h"
#import "AMASessionsCleaner.h"
#import "AMAReportRequestProvider.h"
#import "AMAEventLogger.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAStartupParametersConfiguration.h"
#import "AMAReportRequestModel.h"
#import "AMADataSendingRestrictionController.h"
#import "AMAReachability.h"
#import "AMAReporterStoragesContainer.h"
#import "AMAReporterStorage.h"
#import "AMAReporterStateStorage.h"
#import "AMADatabaseProtocol.h"
#import "AMAProxyReportsController.h"

NSString *const kAMADispatcherErrorDomain = @"io.appmetrica.AMADispatcher";
NSString *const kAMADispatcherErrorApiKeyUserInfoKey = @"kAMADispatcherErrorApiKeyUserInfoKey";

@interface AMADispatcher () <AMAReportsControllerDelegate>

@property (nonatomic, assign, readonly) BOOL main;
@property (nonatomic, strong, readonly) id<AMAAsyncExecuting> executor;
@property (nonatomic, strong, readonly) AMAReporterStorage *reporterStorage;
@property (nonatomic, strong, readonly) id<AMAReportsControlling> reportsController;

@end

@implementation AMADispatcher

- (instancetype)initWithReporterStorage:(AMAReporterStorage *)reporterStorage
                                   main:(BOOL)main
                reportTimeoutController:(AMATimeoutRequestsController *)reportTimeoutController
              trackingTimeoutController:(AMATimeoutRequestsController *)trackingTimeoutController
{
    id<AMAAsyncExecuting> executor = [[AMAExecutor alloc] initWithIdentifier:self];

    AMAProxyReportsController *reportsController = [[AMAProxyReportsController alloc] initWithExecutor:executor
                                                                       reportTimeoutRequestsController:reportTimeoutController
                                                                     trackingTimeoutRequestsController:trackingTimeoutController];


    reportsController.delegate = self;
    return [self initWithReporterStorage:reporterStorage
                                    main:main
                                executor:executor
                       reportsController:reportsController];
}

- (instancetype)initWithReporterStorage:(AMAReporterStorage *)reporterStorage
                                   main:(BOOL)main
                               executor:(id<AMAAsyncExecuting>)executor
                      reportsController:(id<AMAReportsControlling>)reportsController
{
    self = [super init];
    if (self != nil) {
        _reporterStorage = reporterStorage;
        _main = main;
        _executor = executor;
        _reportsController = reportsController;
    }
    return self;
}

#pragma mark - Public -

- (NSString *)apiKey
{
    return self.reporterStorage.apiKey;
}

- (void)cancelPending
{
    [self.executor execute:^{
        AMALogInfo(@"Canceling pending requests");
        [self.reportsController cancelPendingRequests];
    }];
}

- (void)performReport
{
    [self.executor execute:^{
        [self performSyncReport];
    }];
}

#pragma mark - Private -

- (void)purgeIfNeededForError:(NSError *)error requestModel:(AMAReportRequestModel *)requestModel
{
    if ([error.domain isEqualToString:kAMAReportsControllerErrorDomain]) {
        switch (error.code) {
            case AMAReportsControllerErrorBadRequest:
                [self handleRequestMarkedComplete:requestModel cleanupReason:AMAEventsCleanupReasonTypeBadRequest];
                break;

            case AMAReportsControllerErrorRequestEntityTooLarge:
                [self handleRequestMarkedComplete:requestModel cleanupReason:AMAEventsCleanupReasonTypeEntityTooLarge];
                break;

            default:
                break;
        }
    }
}

- (void)handleRequestMarkedComplete:(AMAReportRequestModel *)requestModel
                      cleanupReason:(AMAEventsCleanupReasonType)cleanupReason
{
    [self.reporterStorage.sessionsCleaner purgeSessionWithRequestModel:requestModel reason:cleanupReason];
    id<AMAKeyValueStoring> storage = self.reporterStorage.keyValueStorageProvider.cachingStorage;
    [self.reporterStorage.stateStorage.requestIDStorage nextInStorage:storage
                                                             rollback:nil
                                                                error:nil];
}

- (NSError *)errorWithCode:(AMADispatcherReportErrorCode)code apiKey:(NSString *)apiKey
{
    return [NSError errorWithDomain:kAMADispatcherErrorDomain
                               code:code
                           userInfo:apiKey != nil ? @{ kAMADispatcherErrorApiKeyUserInfoKey : apiKey } : nil];
}

- (void)performSyncReport
{
    NSError *error = nil;

    BOOL canPerformDispatch = [self canPerformDispatchWithApiKey:self.reporterStorage.apiKey error:&error];

    if (canPerformDispatch == NO) {
        [self didFailToReportWithError:error];
        return;
    }

    [[AMAReporterStoragesContainer sharedInstance] waitMigrationForApiKey:self.reporterStorage.apiKey];

    NSArray *requestModels = [self.reporterStorage.reportRequestProvider requestModels];
    BOOL isDataToSendAvailable = requestModels.count != 0;
    if (isDataToSendAvailable == NO) {
        AMALogInfo(@"No more data to send to apiKey %@", self.reporterStorage.apiKey);
        if ([self.delegate respondsToSelector:@selector(dispatcherWillFinishDispatching:)]) {
            [self.delegate dispatcherWillFinishDispatching:self];
        }
        return;
    }

    if (requestModels.count > 0) {
        AMALogInfo(@"Performing report to apiKey: %@. Requests count: %lu.",
                           self.reporterStorage.apiKey, (unsigned long)requestModels.count);
        [self.reportsController reportRequestModelsFromArray:requestModels];
    }
}

- (BOOL)canPerformDispatchWithApiKey:(NSString *)apiKey error:(NSError **)error
{
    AMAReachability *reachability = [AMAReachability sharedInstance];
    if ([[AMADataSendingRestrictionController sharedInstance] shouldReportToApiKey:apiKey] == NO) {
        AMALogWarn(@"Can't report to apiKey %@, data sending is disabled", apiKey);
        *error = [self errorWithCode:AMADispatcherReportErrorDataSendingForbidden apiKey:apiKey];
    }
    else if ([AMAMetricaConfiguration sharedInstance].startup.reportHosts.count == 0) {
        AMALogWarn(@"Can't report to apiKey %@, reportHost is unknown", apiKey);
        *error = [self errorWithCode:AMADispatcherReportErrorNoHosts apiKey:apiKey];
    }
    else if ([AMAMetricaConfiguration sharedInstance].persistent.deviceID.length == 0) {
        AMALogWarn(@"Can't report to apiKey %@, deviceID is unknown", apiKey);
        *error = [self errorWithCode:AMADispatcherReportErrorNoDeviceId apiKey:apiKey];
    }
    else if (self.main && [AMAMetricaConfiguration sharedInstance].persistent.checkedInitialAttribution == NO) {
        AMALogWarn(@"Can't report to apiKey %@, did not check initial attribution", apiKey);
        *error = [self errorWithCode:AMADispatcherReportErrorDidNotCheckInitialAttribution apiKey:apiKey];
    }
    else if (reachability.isNetworkReachable == NO && reachability.status != AMAReachabilityStatusUnknown) {
        AMALogWarn(@"Can't report to apiKey %@, no network has been found", apiKey);
        *error = [self errorWithCode:AMADispatcherReportErrorNoNetworkAvailiable apiKey:apiKey];
    }
    return *error == nil;
}

#pragma mark - AMAReportControllerDelegate -

- (NSString *)reportsControllerNextRequestIdentifierForController:(id<AMAReportsControlling>)controller
{
    id<AMAKeyValueStoring> storage = self.reporterStorage.keyValueStorageProvider.cachingStorage;
    NSNumber *requestIdentifier = [self.reporterStorage.stateStorage.requestIDStorage valueWithStorage:storage];
    return requestIdentifier.stringValue;
}

- (void)reportsController:(id<AMAReportsControlling>)controller didReportRequest:(AMAReportRequestModel *)requestModel
{
    for (AMAEvent *event in requestModel.events) {
        [[AMAEventLogger sharedInstanceForApiKey:requestModel.apiKey] logEventSent:event];
    }
    [self handleRequestMarkedComplete:requestModel cleanupReason:AMAEventsCleanupReasonTypeSuccessfulReport];
}

- (void)reportsControllerDidFinishWithSuccess:(id<AMAReportsControlling>)controller
{
    [self.executor execute:^{
        [self.delegate dispatcherDidPerformReport:self];
    }];
}

- (void)reportsController:(id<AMAReportsControlling>)controller
           didFailRequest:(AMAReportRequestModel *)requestModel
                withError:(NSError *)innerError
{
    [self purgeIfNeededForError:innerError requestModel:requestModel];

    NSDictionary *outerUserInfo = nil;
    if (innerError != nil) {
        outerUserInfo = @{ NSUnderlyingErrorKey : innerError };
    }
    NSError *error = [NSError errorWithDomain:kAMADispatcherErrorDomain
                                         code:AMADispatcherReportErrorNetwork
                                     userInfo:outerUserInfo];
    [self.executor execute:^{
        [self didFailToReportWithError:error];
    }];
}

- (void)didFailToReportWithError:(NSError *)error
{
    [self.delegate dispatcher:self didFailToReportWithError:error];
}

@end
