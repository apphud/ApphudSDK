#import <AppMetricaStorageUtils/AppMetricaStorageUtils.h>
#import <AppMetricaCoreExtension/AppMetricaCoreExtension.h>
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import <AppMetricaHostState/AppMetricaHostState.h>
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMAAppMetricaCrashes.h"
#import "AMAAppMetricaCrashes+Private.h"
#import "AMAANRWatchdog.h"
#import "AMACrashContext.h"
#import "AMACrashEventType.h"
#import "AMACrashLoader.h"
#import "AMACrashLogger.h"
#import "AMACrashLogging.h"
#import "AMAExtendedCrashProcessing.h"
#import "AMACrashProcessor.h"
#import "AMACrashReporter.h"
#import "AMACrashReportingStateNotifier.h"
#import "AMACrashSafeTransactor.h"
#import "AMAAppMetricaCrashesConfiguration.h"
#import "AMADecodedCrash.h"
#import "AMADecodedCrashSerializer+CustomEventParameters.h"
#import "AMADecodedCrashSerializer.h"
#import "AMAErrorEnvironment.h"
#import "AMAAppMetricaPluginsImpl.h"
#import "AMACrashReportersContainer.h"
#import "AMAAppMetricaCrashReporting.h"
#import "AMACrashReportCrash.h"
#import "AMACrashReportError.h"
#import "AMASignal.h"
#import "AMAAppMetricaPluginsImpl.h"
#import "AMABuildUID.h"

@interface AMAAppMetricaCrashes ()

@property (nonatomic, strong) AMACrashProcessor *crashProcessor;
@property (nonatomic, strong) AMACrashReportingStateNotifier *stateNotifier;
@property (nonatomic, strong) id<AMAAsyncExecuting, AMASyncExecuting> executor;
@property (nonatomic, strong) AMAANRWatchdog *ANRDetector;

@property (nonatomic, strong) AMAEnvironmentContainer *appEnvironment;
@property (nonatomic, strong) AMAErrorEnvironment *errorEnvironment;

@property (nonatomic, strong) AMACrashReportersContainer *reportersContainer;

@property (nonatomic, strong, readonly) id<AMAHostStateProviding> hostStateProvider;
@property (nonatomic, strong, readonly) AMADecodedCrashSerializer *serializer;
@property (nonatomic, strong, readwrite) NSString *apiKey;

@property (nonatomic, strong) NSMutableSet<id<AMAExtendedCrashProcessing>> *extendedCrashProcessors;

@property (nonatomic, strong) AMAAppMetricaPluginsImpl *pluginsImpl;

@end

@implementation AMAAppMetricaCrashes

@synthesize activated = _activated;

+ (void)load
{
    [AMAAppMetrica addActivationDelegate:self];
    [AMAAppMetrica addEventPollingDelegate:self];
}

+ (void)initialize
{
    if (self == [AMAAppMetricaCrashes class]) {
        [AMAAppMetrica.sharedLogConfigurator setupLogWithChannel:AMA_LOG_CHANNEL];
        [AMAAppMetrica.sharedLogConfigurator setChannel:AMA_LOG_CHANNEL enabled:NO];
    }
}

+ (instancetype)crashes
{
    static AMAAppMetricaCrashes *sharedInstance = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedInstance = [[self alloc] init];
    });
    return sharedInstance;
}

- (instancetype)init
{
    AMAExecutor *executor = [[AMAExecutor alloc] initWithIdentifier:self];
    AMAUserDefaultsStorage *storage = [[AMAUserDefaultsStorage alloc] init];
    AMAUnhandledCrashDetector *detector = [[AMAUnhandledCrashDetector alloc] initWithStorage:storage executor:executor];
    AMACrashSafeTransactor *transactor = [[AMACrashSafeTransactor alloc] initWithReporter:nil];

    return [self initWithExecutor:executor
                      crashLoader:[[AMACrashLoader alloc] initWithUnhandledCrashDetector:detector transactor:transactor]
                    stateNotifier:[[AMACrashReportingStateNotifier alloc] init]
                hostStateProvider:[[AMAHostStateProvider alloc] init]
                       serializer:[[AMADecodedCrashSerializer alloc] init]
                    configuration:[[AMAAppMetricaCrashesConfiguration alloc] init]];
}

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting, AMASyncExecuting>)executor
                     crashLoader:(AMACrashLoader *)crashLoader
                   stateNotifier:(AMACrashReportingStateNotifier *)stateNotifier
               hostStateProvider:(id<AMAHostStateProviding>)hostStateProvider
                      serializer:(AMADecodedCrashSerializer *)serializer
                   configuration:(AMAAppMetricaCrashesConfiguration *)configuration
{
    self = [super init];
    if (self != nil) {
        _executor = executor;
        _crashProcessor = nil;
        _apiKey = nil;
        _reportersContainer = [[AMACrashReportersContainer alloc] init];
        _crashLoader = crashLoader;
        _stateNotifier = stateNotifier;
        _hostStateProvider = hostStateProvider;
        _hostStateProvider.delegate = self;
        _extendedCrashProcessors = [NSMutableSet new];
        _serializer = serializer;
        _internalConfiguration = configuration;
        _errorEnvironment = [AMAErrorEnvironment new];
        _pluginsImpl = [[AMAAppMetricaPluginsImpl alloc] init];
    }
    return self;
}

#pragma mark - Public -

- (id<AMAAppMetricaCrashReporting>)reporterForAPIKey:(NSString *)apiKey
{
    id<AMAAppMetricaCrashReporting> crashReporter = [self.reportersContainer reporterForAPIKey:apiKey];
    if (crashReporter == nil) {
        crashReporter = [[AMACrashReporter alloc] initWithApiKey:apiKey errorEnvironment:self.errorEnvironment];
        [self.reportersContainer setReporter:crashReporter forAPIKey:apiKey];
    }
    return crashReporter;
}

- (void)setConfiguration:(AMAAppMetricaCrashesConfiguration *)configuration
{
    if (configuration == nil) {
        return;
    }

    if (self.isActivated == NO) {
        @synchronized (self) {
            if (self.isActivated == NO) {
                self.internalConfiguration = [configuration copy];
            }
        }
    }
}

- (void)reportNSError:(NSError *)error onFailure:(void (^)(NSError *))onFailure
{
    if (self.isActivated) {
        [self.mainCrashReporter reportNSError:error
                                    onFailure:onFailure];
    }
}

- (void)reportNSError:(NSError *)error
              options:(AMAErrorReportingOptions)options
            onFailure:(void (^)(NSError *))onFailure
{
    if (self.isActivated) {
        [self.mainCrashReporter reportNSError:error
                                      options:options
                                    onFailure:onFailure];
    }
}

- (void)reportError:(id<AMAErrorRepresentable>)error onFailure:(void (^)(NSError *))onFailure
{
    if (self.isActivated) {
        [self.mainCrashReporter reportError:error
                                  onFailure:onFailure];
    }
}

- (void)reportError:(id<AMAErrorRepresentable>)error
            options:(AMAErrorReportingOptions)options
          onFailure:(void (^)(NSError *))onFailure
{
    if (self.isActivated) {
        [self.mainCrashReporter reportError:error
                                    options:options
                                  onFailure:onFailure];
    }
}

- (void)setErrorEnvironmentValue:(NSString *)value forKey:(NSString *)key
{
    [self execute:^{
        [self.errorEnvironment addValue:value forKey:key];
        [self.mainCrashReporter setErrorEnvironmentValue:value forKey:key];
        [self updateCrashContextQuickly:YES];
        
    }];
}

- (void)clearErrorEnvironment
{
    [self execute:^{
        [self.errorEnvironment clearEnvironment];
        [self.mainCrashReporter clearErrorEnvironment];
        [self updateCrashContextQuickly:YES];
        
    }];
}

- (id<AMAAppMetricaPlugins>)pluginExtension
{
    return self.pluginsImpl;
}

- (void)enableANRMonitoring
{
    [self enableANRMonitoringWithWatchdogInterval:4.0 pingInterval:0.1];
}

- (void)enableANRMonitoringWithWatchdogInterval:(NSTimeInterval)watchdog pingInterval:(NSTimeInterval)ping
{
    if (self.isActivated) {
        [self enableANRWatchdogWithWatchdogInterval:watchdog pingInterval:ping];
    }
}

#pragma mark - Internal -

- (void)activate
{
    AMAAppMetricaCrashesConfiguration *config = nil;
    @synchronized (self) {
        self.activated = YES;
        config = self.internalConfiguration;
    }

    if (config.autoCrashTracking) {
        if (config.applicationNotRespondingDetection) {
            [self enableANRWatchdogWithWatchdogInterval:config.applicationNotRespondingWatchdogInterval
                                           pingInterval:config.applicationNotRespondingPingInterval];
        }
        [self setupCrashLoaderWithDetection:config.probablyUnhandledCrashReporting];
        [self loadCrashReports];
    }
    else {
        [self setupRequiredMonitoring];
        [self cleanupCrashes];
    }
    [self notifyState];
    [self updateCrashContextAsync];
}

- (void)setupReporterWithConfiguration:(AMAModuleActivationConfiguration *)configuration
{
    AMACrashReporter *crashReporter = [[AMACrashReporter alloc] initWithApiKey:configuration.apiKey
                                                              errorEnvironment:self.errorEnvironment];
    [self.reportersContainer setReporter:crashReporter forAPIKey:configuration.apiKey];
    self.apiKey = configuration.apiKey;
    
    [self setupCrashProcessorWithCrashReporter:crashReporter ignoredSignals:self.internalConfiguration.ignoredCrashSignals];
    
    [self.pluginsImpl setupCrashReporter:crashReporter];
}

- (void)setupCrashProcessorWithCrashReporter:(AMACrashReporter *)crashReporter ignoredSignals:(NSArray<NSNumber *> *)ignoredSignals
{
    [self execute:^{
        self.crashProcessor = [[AMACrashProcessor alloc] initWithIgnoredSignals:ignoredSignals
                                                                     serializer:self.serializer
                                                                  crashReporter:crashReporter
                                                             extendedProcessors:[self.extendedCrashProcessors allObjects]];
    }];
}

- (void)requestCrashReportingStateWithCompletionQueue:(dispatch_queue_t)completionQueue
                                      completionBlock:(AMACrashReportingStateCompletionBlock)completionBlock
{
    [self.stateNotifier addObserverWithCompletionQueue:completionQueue completionBlock:completionBlock];
    [self notifyState];
}

- (void)enableANRWatchdogWithWatchdogInterval:(NSTimeInterval)watchdogInterval
                                 pingInterval:(NSTimeInterval)pingInterval
{
    [self execute:^{
        [self.ANRDetector cancel];
        self.ANRDetector = [[AMAANRWatchdog alloc] initWithWatchdogInterval:watchdogInterval
                                                               pingInterval:pingInterval];
        self.ANRDetector.delegate = self;
        [self.ANRDetector start];
    }];
}

- (id<AMAAppMetricaCrashReporting>)mainCrashReporter
{
    if (self.apiKey != nil) {
        return [self reporterForAPIKey:self.apiKey];
    }
    return nil;
}

#pragma mark - Properties
/* Setter methods below allow internal write access to properties marked 'readonly' in the +Private extension.
In Objective-C, properties can't be redefined in class extensions. Thus, private setters are used to modify
them while retaining external immutability. Needed for testability. */

- (void)setActivated:(BOOL)activated
{
    @synchronized (self) {
        _activated = activated;
    }
}

- (BOOL)isActivated
{
    @synchronized (self) {
        return _activated;
    }
}

- (void)setInternalConfiguration:(AMAAppMetricaCrashesConfiguration *)internalConfiguration
{
    _internalConfiguration = internalConfiguration;
}

#pragma mark - Private -
- (void)handlePluginInitFinished
{
    if (AMAAppMetrica.isActivated) {
        [self.hostStateProvider forceUpdateToForeground];
    }
}

#pragma mark - Activation

- (void)setupCrashLoaderWithDetection:(BOOL)enabled
{
    [self.crashLoader setDelegate:self];
    self.crashLoader.isUnhandledCrashDetectingEnabled = enabled;
    [self.crashLoader enableCrashLoader];
}

- (void)setupRequiredMonitoring
{
    [self.crashLoader enableRequiredMonitoring];
}

- (void)updateCrashContextAsync
{
    [self execute:^{
        [self updateCrashContextQuickly:NO];
    }];
}

- (void)cleanupCrashes
{
    [self execute:^{
        [AMACrashLoader purgeCrashesDirectory];
    }];
}

- (void)loadCrashReports
{
    [self execute:^{
        [self.crashLoader loadCrashReports];
    }];
}

- (void)updateCrashContextQuickly:(BOOL)isQuickly
{
    AMAApplicationState *appState = isQuickly ?
        AMAApplicationStateManager.quickApplicationState :
        AMAApplicationStateManager.applicationState;

    NSDictionary *context = @{
        kAMACrashContextAppBuildUIDKey : AMABuildUID.buildUID.stringValue ?: @"",
        kAMACrashContextAppStateKey : appState.dictionaryRepresentation ?: @{},
        kAMACrashContextErrorEnvironmentKey : self.errorEnvironment.currentEnvironment ?: @{},
        kAMACrashContextAppEnvironmentKey : self.appEnvironment.dictionaryEnvironment ?: @{},
    };

    [AMACrashLoader addCrashContext:context];
}

- (void)notifyState
{
    [self execute:^{
        if (self.isActivated) {
            [self.stateNotifier notifyWithEnabled:self.internalConfiguration.autoCrashTracking
                                crashedLastLaunch:self.crashLoader.crashedLastLaunch];
        }
    }];
}

- (void)execute:(dispatch_block_t)block
{
    [self.executor execute:block];
}

- (NSArray<AMAEventPollingParameters *> *)eventsForPreviousSession
{
    __weak typeof(self) weakSelf = self;
    return [self.executor syncExecute:^id{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        NSArray<AMADecodedCrash *> *crashes = [AMACollectionUtilities filteredArray:[strongSelf.crashLoader syncLoadCrashReports]
                                                                      withPredicate:^BOOL(AMADecodedCrash *crash) {
            if (self.internalConfiguration.ignoredCrashSignals != nil) {
                return [self.internalConfiguration.ignoredCrashSignals containsObject:@(crash.crash.error.signal.signal)];
            }
            return YES;
        }];
        
        return [AMACollectionUtilities mapArray:crashes withBlock:^AMAEventPollingParameters *(AMADecodedCrash *item) {
            return [strongSelf.serializer eventParametersFromDecodedData:item error:NULL];
        }];
    }];
}

#pragma mark - AMAModuleActivationDelegate

+ (void)willActivateWithConfiguration:(__unused AMAModuleActivationConfiguration *)configuration
{
    [[[self class] crashes] activate];
}

+ (void)didActivateWithConfiguration:(__unused AMAModuleActivationConfiguration *)configuration
{
    [[[self class] crashes] setupReporterWithConfiguration:configuration];
}

#pragma mark - AMAEventPollingDelegate

+ (NSArray<AMAEventPollingParameters *> *)eventsForPreviousSession
{
    return [[[self class] crashes] eventsForPreviousSession];
}

+ (void)setupAppEnvironment:(AMAEnvironmentContainer *)appEnvironment
{
    AMAAppMetricaCrashes *crashes = [[self class] crashes];
    [crashes setupAppEnvironment:appEnvironment];
}

- (void)setupAppEnvironment:(AMAEnvironmentContainer *)appEnvironment
{
    [self execute:^{
        [self.appEnvironment removeObserver:self];
        
        self.appEnvironment = appEnvironment;
        
        [self updateCrashContextQuickly:NO];
        
        [self.appEnvironment addObserver:self withBlock:^(AMAAppMetricaCrashes *crashes, AMAEnvironmentContainer *e) {
            [crashes updateCrashContextAsync];
        }];
    }];
}

#pragma mark - AMACrashLoaderDelegate

- (void)crashLoader:(AMACrashLoader *)crashLoader
       didLoadCrash:(AMADecodedCrash *)decodedCrash
          withError:(NSError *)error
{
    __weak typeof(self) weakSelf = self;
    [self execute:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.crashProcessor processCrash:decodedCrash withError:error];
    }];
}

- (void)crashLoader:(AMACrashLoader *)crashLoader
         didLoadANR:(AMADecodedCrash *)decodedCrash
          withError:(NSError *)error
{
    __weak typeof(self) weakSelf = self;
    [self execute:^{
        __strong typeof(weakSelf) strongSelf = weakSelf;
        [strongSelf.crashProcessor processANR:decodedCrash withError:error];
    }];
}

- (void)crashLoader:(AMACrashLoader *)crashLoader didDetectProbableUnhandledCrash:(AMAUnhandledCrashType)crashType
{
    if (crashType == AMAUnhandledCrashForeground || crashType == AMAUnhandledCrashBackground) {
        AMALogInfo(@"Reporting probably unhandled crash");
        NSString *errorMessage = [[self class] errorMessageForProbableUnhandledCrash:crashType];
        NSError *error = [AMAErrorUtilities internalErrorWithCode:AMAAppMetricaInternalEventErrorCodeProbableUnhandledCrash
                                                      description:errorMessage];
        [self.crashProcessor processError:error];
    }
}

+ (NSString *)errorMessageForProbableUnhandledCrash:(AMAUnhandledCrashType)crashType
{
    NSString *errorMessage = nil;
    if(crashType == AMAUnhandledCrashForeground) {
        errorMessage = @"Detected probable unhandled exception when app was "
                        "in foreground. Exception mean that previous working session have not finished correctly.";
    }
    else if(crashType == AMAUnhandledCrashBackground) {
        errorMessage = @"Detected probable unhandled exception when app was "
                        "in background. Exception mean that previous working session have not finished correctly.";
    }
    return errorMessage;
}

#pragma mark - AMAANRWatchdogDelegate

- (void)ANRWatchdogDidDetectANR:(AMAANRWatchdog *)detector
{
    [self execute:^{
        AMALogInfo(@"Reporting of ANR crash.");
        [self.crashLoader reportANR];
    }];
}

#pragma mark - AMAHostStateProviderDelegate

- (void)hostStateDidChange:(AMAHostAppState)hostState
{
    switch (hostState) {
        case AMAHostAppStateBackground:
            [self.ANRDetector cancel];
            break;
        case AMAHostAppStateForeground:
            [self.ANRDetector start];
            break;
        default:
            break;
    }
}

#pragma mark - ExtendedCrashProcessors

- (void)addExtendedCrashProcessor:(id<AMAExtendedCrashProcessing>)crashProcessor
{
    if (crashProcessor != nil) {
        [self execute:^{
            [self.extendedCrashProcessors addObject:crashProcessor];
        }];
    }
}

@end
