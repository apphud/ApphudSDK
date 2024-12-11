#import "AMACrashLogging.h"
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMACrashLoader.h"
#import "AMACrashReportDecoder.h"
#import "AMACrashSafeTransactor.h"
#import "AMADecodedCrash.h"
#import "AMAKSCrash.h"
#import "AMAKSCrashImports.h"

static NSString *const kAMALoadingCrashReportsTransactionKey = @"KSCrashLoadingReports";
NSString *const kAMAApplicationNotRespondingCrashType = @"AMAApplicationNotRespondingCrashType";

@interface AMACrashLoader () <AMACrashReportDecoderDelegate>

@property (nonatomic, strong) NSMutableDictionary *decoders;
@property (nonatomic, strong) AMAUnhandledCrashDetector *unhandledCrashDetector;
@property (nonatomic, strong, readonly) AMACrashSafeTransactor *transactor;

@property (nonatomic, assign) BOOL enabled;

@property (nonatomic, strong) NSMutableArray *syncLoadedCrashes;

@end

@implementation AMACrashLoader

- (instancetype)initWithUnhandledCrashDetector:(AMAUnhandledCrashDetector *)unhandledCrashDetector
                                    transactor:(AMACrashSafeTransactor *)transactor
{
    self = [super init];
    if (self != nil)
    {
        _decoders = [NSMutableDictionary dictionary];
        _unhandledCrashDetector = unhandledCrashDetector;
        _transactor = transactor;
    }
    return self;
}

- (void)dealloc
{
    _delegate = nil;
    _decoders = nil;
}

- (NSNumber *)crashedLastLaunch
{
    return self.enabled ? @(KSCrash.sharedInstance.crashedLastLaunch) : nil;
}

- (void)enableCrashLoader
{
    static dispatch_once_t pred;
    dispatch_once(&pred, ^{
        KSCrashMonitorType monitoring = (
            KSCrashMonitorTypeMachException
            | KSCrashMonitorTypeSignal
            | KSCrashMonitorTypeCPPException
            | KSCrashMonitorTypeNSException
            | KSCrashMonitorTypeUserReported
            | KSCrashMonitorTypeSystem
            | KSCrashMonitorTypeApplicationState
        );
        [self installKSCrashWithMonitoring:monitoring];

        [self.unhandledCrashDetector startDetecting];

        self.enabled = YES;
    });
}

- (void)enableRequiredMonitoring
{
    [self installKSCrashWithMonitoring:KSCrashMonitorTypeRequired];
}

- (void)installKSCrashWithMonitoring:(KSCrashMonitorType)monitoring
{
    if ([AMAPlatformDescription isDebuggerAttached]) {
        AMALogWarn(@"A debugger is attached. Most crashes will not be reported.");
        monitoring &= KSCrashMonitorTypeDebuggerSafe;
    }

    KSCrashConfiguration *config = [KSCrashConfiguration new];
    config.installPath = AMAKSCrash.crashesPath;
    config.enableMemoryIntrospection = NO; // hot fix on arm64
    config.enableQueueNameSearch = NO;
    config.enableSwapCxaThrow = NO;
    config.monitors = monitoring;

    NSError *installationError = nil;
    BOOL handlerInstalled = [[KSCrash sharedInstance] installWithConfiguration:config error:&installationError];

    if (handlerInstalled == NO) {
        AMALogError(@"Could not enable crash reporter. Error: %@", installationError.localizedDescription);
        if (installationError.localizedFailureReason) {
            AMALogError(@"Failure reason: %@", installationError.localizedFailureReason);
        }
    } 
    else {
        AMALogInfo(@"Crash reporter successfully installed with monitoring type: %lu", (unsigned long)monitoring);
    }
}

- (void)shutdown
{
    // do nothing.
}

- (void)loadCrashReports
{
    if (KSCrash.sharedInstance.crashedLastLaunch == NO && self.isUnhandledCrashDetectingEnabled) {
        AMALogInfo(@"No launch crashes detected. Trying to detect unhandled crashes");
        [self.unhandledCrashDetector checkUnhandledCrash:^(AMAUnhandledCrashType crashType) {
            [self.delegate crashLoader:self didDetectProbableUnhandledCrash:crashType];
        }];
    }

    NSArray *__block reportIDs = nil;
    NSString *transactionID = kAMALoadingCrashReportsTransactionKey;
    [self.transactor processTransactionWithID:transactionID name:@"ReportIDs" transaction:^{
        reportIDs = KSCrash.sharedInstance.reportStore.reportIDs;
    } rollback:^NSString *(id context){
        [[self class] purgeAllRawCrashReports];
        return nil;
    }];

    if (reportIDs.count > 0) {
        AMALogInfo(@"Found pending crash reports:\n\t%@", reportIDs);
        [self handleCrashReports:reportIDs];
    }
}
/// Temp implementation: Synchronously loads crash reports. Assumes single-threaded operation.
- (NSArray<AMADecodedCrash *> *)syncLoadCrashReports
{
    self.syncLoadedCrashes = [NSMutableArray array];

    [self loadCrashReports];

    NSArray *result = [self.syncLoadedCrashes copy];
    self.syncLoadedCrashes = nil;

    return result;
}

- (AMACrashReportDecoder *)crashReportDecoderForReportWithID:(NSNumber *)reportID
{
    AMACrashReportDecoder *decoder = self.decoders[reportID];
    if (decoder == nil) {
        decoder = [[AMACrashReportDecoder alloc] initWithCrashID:reportID];
        decoder.delegate = self;
        self.decoders[reportID] = decoder;
    }

    return decoder;
}

- (BOOL)handleCrashReportWithID:(NSNumber *)reportID
{
    __block BOOL success = YES;
    AMACrashReportDecoder *decoder = [self crashReportDecoderForReportWithID:reportID];

    if (decoder != nil) {
        __block KSCrashReportDictionary *crashReport = nil;

        AMACrashSafeTransactorRollbackBlock rollback = ^NSString *(id context) {
            [[self class] purgeAllRawCrashReports];
            success = NO;
            return nil;
        };

        NSString *transactionID = kAMALoadingCrashReportsTransactionKey;
        [self.transactor processTransactionWithID:transactionID name:@"ReportWithID" transaction:^{
            crashReport = [KSCrash.sharedInstance.reportStore reportForID:reportID.longLongValue];
        } rollback:rollback];

        if (success) {
            [self.transactor processTransactionWithID:transactionID
                                                        name:@"DecodeReport"
                                             rollbackContext:[reportID stringValue]
                                                 transaction:^{
                [decoder decode:crashReport.value];
            } rollback:rollback];
        }
    }

    return success;
}

- (void)handleCrashReports:(NSArray *)reportIDs
{
    for (NSNumber *reportID in reportIDs) {
        if ([self handleCrashReportWithID:reportID] == NO) {
            break;
        }
    }
}

+ (void)purgeAllRawCrashReports
{
    [KSCrash.sharedInstance.reportStore deleteAllReports];
}

+ (void)purgeCrashesDirectory
{
    [AMAFileUtility deleteFileAtPath:[AMAKSCrash crashesPath]];
}

+ (void)addCrashContext:(NSDictionary *)crashContext
{
    if (crashContext.count == 0) {
        return;
    }

    NSDictionary *existingContext = [self crashContext];
    NSDictionary *newContext = nil;

    if (existingContext != nil) {
        NSMutableDictionary *currentContext = [existingContext mutableCopy];
        [currentContext addEntriesFromDictionary:crashContext];
        newContext = [currentContext copy];
    } else {
        newContext = [crashContext copy];
    }

    KSCrash.sharedInstance.userInfo = newContext;
}

+ (NSDictionary *)crashContext
{
    return KSCrash.sharedInstance.userInfo;
}

- (void)reportANR
{
    [[KSCrash sharedInstance] reportUserException:kAMAApplicationNotRespondingCrashType
                                           reason:@"The main thread was unresponsive for too long"
                                         language:@"ObjC"
                                       lineOfCode:nil
                                       stackTrace:nil
                                    logAllThreads:YES
                                 terminateProgram:NO];
    [self loadCrashReports];
}

#pragma mark - AMACrashReportDecoderDelegate Implementation

- (void)crashReportDecoder:(AMACrashReportDecoder *)decoder
            didDecodeCrash:(AMADecodedCrash *)decodedCrash
                 withError:(NSError *)error
{
    if (error != nil) {
        AMALogError(@"Failed to decode report:%@ with error: %@", decoder.crashID, error);
    }

    if (decoder.crashID != nil) {
        [self.decoders removeObjectForKey:decoder.crashID];
    }

    if (self.syncLoadedCrashes != nil) {
        if (decodedCrash != nil && error == nil) {
            [self.syncLoadedCrashes addObject:decodedCrash];
        }
    }
    else {
        [self.delegate crashLoader:self didLoadCrash:decodedCrash withError:error];
    }

    [[self class] purgeRawCrashReport:decoder.crashID];
}

- (void)crashReportDecoder:(AMACrashReportDecoder *)decoder
              didDecodeANR:(AMADecodedCrash *)decodedCrash
                 withError:(NSError *)error
{
    if (error != nil) {
        AMALogInfo(@"Failed to decode ANR report:%@ with error: %@", decoder.crashID, error);
    }

    if (decoder.crashID != nil) {
        [self.decoders removeObjectForKey:decoder.crashID];
    }

    if (self.syncLoadedCrashes != nil) {
        if (decodedCrash != nil && error == nil) {
            [self.syncLoadedCrashes addObject:decodedCrash];
        }
    }
    else {
        [self.delegate crashLoader:self didLoadANR:decodedCrash withError:error];
    }

    [[self class] purgeRawCrashReport:decoder.crashID];
}

#pragma mark - AMACrashReportControllerDelegate Implementation

+ (void)purgeRawCrashReport:(NSNumber *)reportID
{
    AMALogInfo(@"Will purge report with ID: %@", reportID);
    [KSCrash.sharedInstance.reportStore deleteReportWithID:reportID.integerValue];

#ifdef DEBUG
    NSArray *reports = KSCrash.sharedInstance.reportStore.reportIDs;
    if ([reports containsObject:reportID] == NO) {
        AMALogAssert(@"FAILED TO REMOVE REPORT: %@", reportID);
    }
#endif
}

@end
