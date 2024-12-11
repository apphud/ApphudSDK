
#import "AMACrashLogging.h"
#import "AMAUnhandledCrashDetector.h"
#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import <AppMetricaPlatform/AppMetricaPlatform.h>

@interface AMAUnhandledCrashDetector()

@property (nonatomic, strong) AMAHostStateProvider *hostStateProvider;
@property (nonatomic, strong) AMAUserDefaultsStorage *storage;
@property (nonatomic, strong, readonly) id<AMAAsyncExecuting> executor;

@property (nonatomic, copy) NSString *previousBundleVersion;
@property (nonatomic, copy) NSString *previousOSVersion;
@property (nonatomic, assign) BOOL appWasTerminated;
@property (nonatomic, assign) BOOL appWasInBackground;

@end

@implementation AMAUnhandledCrashDetector

- (instancetype)initWithStorage:(AMAUserDefaultsStorage *)storage
                       executor:(id<AMAAsyncExecuting>)executor
{
    return [self initWithStorage:storage
               hostStateProvider:[[AMAHostStateProvider alloc] init]
                        executor:executor];
}


- (instancetype)initWithStorage:(AMAUserDefaultsStorage *)storage
              hostStateProvider:(id<AMAHostStateProviding>)hostStateProvider
                       executor:(id<AMAAsyncExecuting>)executor
{
    self = [super init];
    if (self != nil) {
        _storage = storage;
        _hostStateProvider = hostStateProvider;
        _executor = executor;
    }

    return self;
}

- (void)startDetecting
{
    [self.executor execute:^{
        AMALogInfo(@"Start detecting probably unhandled crashes");
        [self loadState];
        [self makeStateSnapshot];
        [self startMonitoringAppState];
    }];
}

- (void)checkUnhandledCrash:(AMAUnhandledCrashCallback)unhandledCrashCallback
{
    AMAUnhandledCrashType crashType = AMAUnhandledCrashUnknown;
    BOOL didDetectUnhandledCrash =
        [self.previousOSVersion isEqualToString:[[self class] currentOSVersion]] &&
        [self.previousBundleVersion isEqualToString:[[self class] currentBundleVersion]] &&
        self.appWasTerminated == NO;

    if (didDetectUnhandledCrash) {
        AMALogInfo(@"Did detect possible unhandled crash");
        crashType = self.appWasInBackground ? AMAUnhandledCrashBackground : AMAUnhandledCrashForeground;
    }
    if (unhandledCrashCallback != nil) {
        unhandledCrashCallback(crashType);
    }
}

- (void)loadState
{
    self.previousBundleVersion = [self.storage stringForKey:kAMAUserDefaultsStringKeyPreviousBundleVersion];
    self.previousOSVersion = [self.storage stringForKey:kAMAUserDefaultsStringKeyPreviousOSVersion];
    self.appWasTerminated = [self.storage boolForKey:kAMAUserDefaultsStringKeyAppWasTerminated];
    self.appWasInBackground = [self.storage boolForKey:kAMAUserDefaultsStringKeyAppWasInBackground];
}

- (void)makeStateSnapshot
{
    [self.storage setObject:[AMAUnhandledCrashDetector currentBundleVersion]
                     forKey:kAMAUserDefaultsStringKeyPreviousBundleVersion];
    [self.storage setObject:[AMAUnhandledCrashDetector currentOSVersion]
                     forKey:kAMAUserDefaultsStringKeyPreviousOSVersion];
    [self.storage synchronize];

    [self processCurrentAppState:[self.hostStateProvider hostState]];
}

- (void)startMonitoringAppState
{
    self.hostStateProvider.delegate = self;
}

- (void)processCurrentAppState:(AMAHostAppState)appState
{
    BOOL appWasTerminated = NO;
    BOOL appWasInBackground = YES;
    switch (appState) {
        case AMAHostAppStateTerminated:
            appWasTerminated = YES;
            appWasInBackground = YES;
            break;
        case AMAHostAppStateForeground:
            appWasInBackground = NO;
            appWasTerminated = NO;
            break;
        case AMAHostAppStateBackground:
            appWasTerminated = NO;
            appWasInBackground = YES;
            break;
        default:
            //Do nothing
            break;
    }
    [self.storage setBool:appWasTerminated forKey:kAMAUserDefaultsStringKeyAppWasTerminated];
    [self.storage setBool:appWasInBackground forKey:kAMAUserDefaultsStringKeyAppWasInBackground];
    [self.storage synchronize];
}

- (void)hostStateDidChange:(AMAHostAppState)hostState
{
    [self processCurrentAppState:hostState];
}

- (void)dealloc
{
    self.hostStateProvider.delegate = nil;
}

+ (NSString *)currentBundleVersion
{
    NSString *appBuildNumber = [AMAPlatformDescription appBuildNumber];
    NSString *appVersion = [AMAPlatformDescription appVersionName];
    return [NSString stringWithFormat:@"%@.%@", appVersion, appBuildNumber];
}

+ (NSString *)currentOSVersion
{
    return [AMAPlatformDescription OSVersion];
}

@end
