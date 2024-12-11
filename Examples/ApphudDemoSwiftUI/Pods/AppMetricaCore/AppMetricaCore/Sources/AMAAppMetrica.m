
#import <AppMetricaHostState/AppMetricaHostState.h>
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMACore.h"
#if !TARGET_OS_TV
#import <WebKit/WebKit.h>
#endif
#import "AMAAppMetrica.h"
#import "AMAAdProvider.h"
#import "AMAAdRevenueInfo.h"
#import "AMAAppMetricaConfiguration+Internal.h"
#import "AMAAppMetricaConfiguration.h"
#import "AMAAppMetricaImpl.h"
#import "AMADataSendingRestrictionController.h"
#import "AMADatabaseQueueProvider.h"
#import "AMADeepLinkController.h"
#import "AMAErrorLogger.h"
#import "AMAInternalEventsReporter.h"
#import "AMALocationManager.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaInMemoryConfiguration.h"
#import "AMAMetricaParametersScanner.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAReporterConfiguration+Internal.h"
#import "AMAReporterStoragesContainer.h"
#import "AMARevenueInfo.h"
#import "AMASharedReporterProvider.h"
#import "AMAStartupParametersConfiguration.h"
#import "AMAUUIDProvider.h"
#import "AMAUserProfile.h"
#import "AMAAppMetricaConfigurationManager.h"

NSString *const kAMAUUIDKey = @"appmetrica_uuid";
NSString *const kAMADeviceIDKey = @"appmetrica_deviceID";
NSString *const kAMADeviceIDHashKey = @"appmetrica_deviceIDHash";

NSString *const kAMAAttributionSourceAppsflyer = @"appsflyer";
NSString *const kAMAAttributionSourceAdjust = @"adjust";
NSString *const kAMAAttributionSourceKochava = @"kochava";
NSString *const kAMAAttributionSourceTenjin = @"tenjin";
NSString *const kAMAAttributionSourceAirbridge = @"airbridge";
NSString *const kAMAAttributionSourceSingular = @"singular";

static NSMutableSet<Class<AMAModuleActivationDelegate>> *activationDelegates = nil;
static NSMutableSet<Class<AMAEventFlushableDelegate>> *eventFlushableDelegates = nil;
static NSMutableSet<Class<AMAEventPollingDelegate>> *eventPollingDelegates = nil;

static id<AMAAdProviding> adProvider = nil;
static NSMutableSet<id<AMAExtendedStartupObserving>> *startupObservers = nil;
static NSMutableSet<id<AMAReporterStorageControlling>> *reporterStorageControllers = nil;

@implementation AMAAppMetrica

+ (void)initialize
{
    if (self == [AMAAppMetrica class]) {
        [[self sharedLogConfigurator] setupLogWithChannel:AMA_LOG_CHANNEL];
        [[self class] setLogs:NO];
    }
}

#pragma mark - Core Extension -

+ (void)addActivationDelegate:(Class<AMAModuleActivationDelegate>)delegate
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        activationDelegates = [[NSMutableSet alloc] init];
    });
    @synchronized(self) {
        if ([self isActivated] == NO) {
            [activationDelegates addObject:delegate];
        }
    }
}

+ (void)addEventFlushableDelegate:(Class<AMAEventFlushableDelegate>)delegate
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        eventFlushableDelegates = [[NSMutableSet alloc] init];
    });
    @synchronized(self) {
        if ([self isActivated] == NO) {
            [eventFlushableDelegates addObject:delegate];
        }
    }
}

+ (void)addEventPollingDelegate:(Class<AMAEventPollingDelegate>)delegate
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        eventPollingDelegates = [[NSMutableSet alloc] init];
    });
    @synchronized(self) {
        if ([self isActivated] == NO) {
            [eventPollingDelegates addObject:delegate];
        }
    }
}

+ (void)willActivateDelegates:(AMAAppMetricaConfiguration *)configuration
{
    @synchronized(self) {
        __auto_type moduleConfig = [[AMAModuleActivationConfiguration alloc] initWithApiKey:configuration.APIKey
                                                                                 appVersion:configuration.appVersion
                                                                             appBuildNumber:configuration.appBuildNumber];
        for (Class<AMAModuleActivationDelegate> delegate in activationDelegates) {
            [delegate willActivateWithConfiguration:moduleConfig];
        }
    }
}

+ (void)didActivateDelegates:(AMAAppMetricaConfiguration *)configuration
{
    @synchronized(self) {
        __auto_type moduleConfig = [[AMAModuleActivationConfiguration alloc] initWithApiKey:configuration.APIKey
                                                                                 appVersion:configuration.appVersion
                                                                             appBuildNumber:configuration.appBuildNumber];
        for (Class<AMAModuleActivationDelegate> delegate in activationDelegates) {
            [delegate didActivateWithConfiguration:moduleConfig];
        }
    }
}

+ (void)registerExternalService:(AMAServiceConfiguration *)configuration
{
    @synchronized(self) {
        if (configuration.startupObserver != nil) {
            [[self class] addStartupObserver:configuration.startupObserver];
        }
        if (configuration.reporterStorageController != nil) {
            [[self class] addReporterStorageController:configuration.reporterStorageController];
        }
    }
}

+ (void)addStartupObserver:(id<AMAExtendedStartupObserving>)observer
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        startupObservers = [[NSMutableSet alloc] init];
    });
    @synchronized(self) {
        __weak __typeof(id<AMAExtendedStartupObserving>) weakObserver = observer;
        [startupObservers addObject:weakObserver];
    }
}

+ (void)addReporterStorageController:(id<AMAReporterStorageControlling>)controller
{
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        reporterStorageControllers = [[NSMutableSet alloc] init];
    });
    @synchronized(self) {
        __weak __typeof(id<AMAReporterStorageControlling>) weakController = controller;
        [reporterStorageControllers addObject:weakController];
    }
}

+ (void)registerAdProvider:(id<AMAAdProviding>)provider
{
    @synchronized(self) {
        if ([self isActivated] == NO) {
            adProvider = provider;
        }
    }
}

+ (void)setupExternalServices
{
    @synchronized (self) {
        if ([AMAMetricaConfiguration sharedInstance].inMemory.externalServicesConfigured) {
            return;
        }
        if (startupObservers != nil) {
            [[self sharedImpl] setExtendedStartupObservers:startupObservers];
        }
        if (reporterStorageControllers != nil) {
            [[self sharedImpl] setExtendedReporterStorageControllers:reporterStorageControllers];
        }
        if (adProvider != nil) {
            [[AMAAdProvider sharedInstance] setupAdProvider:adProvider];
        }
        if (eventPollingDelegates != nil) {
            [[self sharedImpl] setEventPollingDelegates:eventPollingDelegates];
        }
        [[AMAMetricaConfiguration sharedInstance].inMemory markExternalServicesConfigured];
    }
}

+ (void)setSessionExtras:(nullable NSData *)data forKey:(NSString *)key
{
    [[self sharedImpl] setSessionExtras:data forKey:key];
}

+ (void)clearSessionExtras
{
    [[self sharedImpl] clearSessionExtras];
}

+ (BOOL)isAPIKeyValid:(NSString *)apiKey
{
    return [AMAIdentifierValidator isValidUUIDKey:apiKey];
}

+ (BOOL)isActivated
{
    @synchronized(self) {
        return [AMAMetricaConfiguration sharedInstance].inMemory.appMetricaStarted ||
               [AMAMetricaConfiguration sharedInstance].inMemory.appMetricaStartedAnonymously;
    }
}

+ (BOOL)isActivatedAsMain
{
    @synchronized(self) {
        return [AMAMetricaConfiguration sharedInstance].inMemory.appMetricaStarted;
    }
}

+ (BOOL)isReporterCreatedForAPIKey:(NSString *)apiKey
{
    @synchronized(self) {
        return [self isMetricaImplCreated] && [[self sharedImpl] isReporterCreatedForAPIKey:apiKey];
    }
}

+ (void)reportEventWithType:(NSUInteger)eventType
                       name:(nullable NSString *)name
                      value:(nullable NSString *)value
           eventEnvironment:(NSDictionary *)eventEnvironment
             appEnvironment:(NSDictionary *)appEnvironment
                  onFailure:(nullable void (^)(NSError *error))onFailure
{
    [self reportEventWithType:eventType
                         name:name
                        value:value
             eventEnvironment:eventEnvironment
               appEnvironment:appEnvironment
                       extras:nil
                    onFailure:onFailure];
}

+ (void)reportEventWithType:(NSUInteger)eventType
                       name:(nullable NSString *)name
                      value:(nullable NSString *)value
           eventEnvironment:(nullable NSDictionary *)eventEnvironment
             appEnvironment:(nullable NSDictionary *)appEnvironment
                     extras:(nullable NSDictionary<NSString *, NSData *> *)extras
                  onFailure:(nullable void (^)(NSError *error))onFailure
{
    if ([self isAppMetricaStartedWithLogging:onFailure]) {
        [[self sharedImpl] reportEventWithType:eventType
                                          name:name
                                         value:value
                              eventEnvironment:eventEnvironment
                                appEnvironment:appEnvironment
                                        extras:extras
                                     onFailure:onFailure];
    }
}

+ (void)reportBinaryEventWithType:(NSUInteger)eventType
                             data:(NSData *)data
                             name:(NSString *)name
                          gZipped:(BOOL)gZipped
                 eventEnvironment:(nullable NSDictionary *)eventEnvironment
                   appEnvironment:(nullable NSDictionary *)appEnvironment
                           extras:(nullable NSDictionary<NSString *, NSData *> *)extras
                   bytesTruncated:(NSUInteger)bytesTruncated
                        onFailure:(nullable void (^)(NSError *error))onFailure
{
    if ([self isAppMetricaStartedWithLogging:onFailure]) {
        [[self sharedImpl] reportBinaryEventWithType:eventType
                                                data:data
                                                name:name
                                             gZipped:gZipped
                                    eventEnvironment:eventEnvironment
                                      appEnvironment:appEnvironment
                                              extras:extras
                                      bytesTruncated:bytesTruncated
                                           onFailure:onFailure];
    }
}

+ (void)reportFileEventWithType:(NSUInteger)eventType
                           data:(NSData *)data
                       fileName:(NSString *)fileName
                        gZipped:(BOOL)gZipped
                      encrypted:(BOOL)encrypted
                      truncated:(BOOL)truncated
               eventEnvironment:(nullable NSDictionary *)eventEnvironment
                 appEnvironment:(nullable NSDictionary *)appEnvironment
                         extras:(nullable NSDictionary<NSString *, NSData *> *)extras
                      onFailure:(nullable void (^)(NSError *error))onFailure
{
    if ([self isAppMetricaStartedWithLogging:onFailure]) {
        [[self sharedImpl] reportFileEventWithType:eventType
                                              data:data
                                          fileName:fileName
                                           gZipped:gZipped
                                         encrypted:encrypted
                                         truncated:truncated
                                  eventEnvironment:eventEnvironment
                                    appEnvironment:appEnvironment
                                            extras:extras
                                         onFailure:onFailure];
    }
}

#pragma mark - Public API -

+ (void)activateWithConfiguration:(AMAAppMetricaConfiguration *)configuration
{
    @synchronized (self) {
        NSString *apiKey = configuration.APIKey;

        if ([self isActivatedAsMain]) {
            [AMAErrorLogger logMetricaAlreadyStartedError];
            return;
        }
        if ([self isAPIKeyValid:apiKey] == NO) {
            [AMAErrorLogger logInvalidApiKeyError:apiKey];
            return;
        }
        if ([self isReporterCreatedForAPIKey:apiKey]) {
            [AMAErrorLogger logMetricaActivationWithAlreadyPresentedKeyError];
            return;
        }
        [[self class] setupExternalServices];
        
        [[self class] willActivateDelegates:configuration];
        
        [[self sharedImpl] activateWithConfiguration:configuration];
        
        [[self class] didActivateDelegates:configuration];
    }
}

+ (void)activate
{
    @synchronized (self) {
        if ([self isActivated]) {
            [AMAErrorLogger logMetricaAlreadyStartedError];
            return;
        }
        
        [[self class] setupExternalServices];
        
        AMAAppMetricaConfiguration *anonymousConfiguration = [[self sharedImpl].configurationManager anonymousConfiguration];
        
        [[self class] willActivateDelegates:anonymousConfiguration];
        
        [[self sharedImpl] scheduleAnonymousActivationIfNeeded];
        
        [[self class] didActivateDelegates:anonymousConfiguration];
    }
}

+ (void)reportEvent:(NSString *)name onFailure:(void (^)(NSError *error))onFailure
{
    [[self class] reportEvent:name parameters:nil onFailure:onFailure];
}

+ (void)reportEvent:(NSString *)name
         parameters:(NSDictionary *)params
          onFailure:(void (^)(NSError *error))onFailure
{
    if ([self isAppMetricaStartedWithLogging:onFailure]) {
        [[self sharedImpl] reportEvent:[name copy] parameters:[params copy] onFailure:onFailure];
    }
}

+ (void)reportUserProfile:(AMAUserProfile *)userProfile onFailure:(nullable void (^)(NSError *error))onFailure
{
    if ([self isAppMetricaStartedWithLogging:onFailure]) {
        [[self sharedImpl] reportUserProfile:[userProfile copy] onFailure:onFailure];
    }
}

+ (void)reportRevenue:(AMARevenueInfo *)revenueInfo onFailure:(nullable void (^)(NSError *error))onFailure
{
    if ([self isAppMetricaStartedWithLogging:onFailure]) {
        [[self sharedImpl] reportRevenue:revenueInfo onFailure:onFailure];
    }
}

+ (void)reportECommerce:(AMAECommerce *)eCommerce onFailure:(void (^)(NSError *))onFailure
{
    if ([self isAppMetricaStartedWithLogging:onFailure]) {
        [[self sharedImpl] reportECommerce:eCommerce onFailure:onFailure];
    }
}

+ (void)reportExternalAttribution:(NSDictionary *)attribution
                           source:(AMAAttributionSource)source
                        onFailure:(nullable void (^)(NSError *error))onFailure
{
    if ([self isAppMetricaStartedWithLogging:onFailure]) {
        [[self sharedImpl] reportExternalAttribution:attribution source:source onFailure:onFailure];
    }
}

+ (void)reportAdRevenue:(AMAAdRevenueInfo *)adRevenue onFailure:(void (^)(NSError *error))onFailure
{
    if ([self isAppMetricaStartedWithLogging:onFailure]) {
        [[self sharedImpl] reportAdRevenue:adRevenue onFailure:onFailure];
    }
}

#if !TARGET_OS_TV
+ (void)setupWebViewReporting:(id<AMAJSControlling>)controller
                    onFailure:(nullable void (^)(NSError *error))onFailure
{
    if ([self isAppMetricaStartedWithLogging:onFailure]) {
        [[self sharedImpl] setupWebViewReporting:controller];
    }
}
#endif

+ (void)setUserProfileID:(NSString *)userProfileID
{
    [[self sharedImpl] setUserProfileID:[userProfileID copy]];
}

+ (NSString *)userProfileID
{
    return [self sharedImpl].userProfileID;
}

+ (void)setLogs:(BOOL)enabled
{
    [[self sharedLogConfigurator] setChannel:AMA_LOG_CHANNEL enabled:enabled];
}

+ (void)setDataSendingEnabled:(BOOL)enabled
{
    AMADataSendingRestriction restriction = enabled
        ? AMADataSendingRestrictionAllowed
        : AMADataSendingRestrictionForbidden;
    [[AMADataSendingRestrictionController sharedInstance] setMainApiKeyRestriction:restriction];
}

#if TARGET_OS_IOS
+ (void)sendMockVisit:(CLVisit *)visit
{
    [[AMALocationManager sharedManager] sendMockVisit:visit];
}
# endif

+ (void)setCustomLocation:(CLLocation *)location
{
    [[AMALocationManager sharedManager] setLocation:location];
    AMALogInfo(@"Set location %@", location);
}

+ (CLLocation *)customLocation
{
    return [AMALocationManager sharedManager].location;
}

+ (void)setLocationTrackingEnabled:(BOOL)enabled
{
    [[AMALocationManager sharedManager] setTrackLocationEnabled:enabled];
    AMALogInfo(@"Set track location enabled %i", enabled);
}

+ (BOOL)isLocationTrackingEnabled
{
    return [AMALocationManager sharedManager].trackLocationEnabled;
}

+ (NSString *)libraryVersion
{
    return [AMAPlatformDescription SDKVersionName];
}

+ (void)trackOpeningURL:(NSURL *)URL
{
    if ([self isActivated] == NO) {
        AMALogWarn(@"Metrica is not started");
        return;
    }
    [[self sharedImpl] reportUrl:URL ofType:kAMADLControllerUrlTypeOpen isAuto:NO];
}

+ (void)setErrorEnvironmentValue:(NSString *)value forKey:(NSString *)key
{
    @synchronized(self) {
        if ([self isMetricaImplCreated]) {
            [[self sharedImpl] setErrorEnvironmentValue:value forKey:key];
        }
        else {
            [AMAAppMetricaImpl syncSetErrorEnvironmentValue:value forKey:key];
        }
    }
}

+ (void)setAppEnvironmentValue:(NSString *)value forKey:(NSString *)key
{
    [[self sharedImpl] setAppEnvironmentValue:value forKey:key];
}

+ (void)clearAppEnvironment
{
    [[self sharedImpl] clearAppEnvironment];
}

+ (void)sendEventsBuffer
{
    if ([self isAppMetricaStartedWithLogging:nil] == NO) { return; }
    [[self sharedImpl] sendEventsBuffer];

    @synchronized(self) {
        for (Class<AMAEventFlushableDelegate> delegate in eventFlushableDelegates) {
            [delegate sendEventsBuffer];
        }
    }
}

+ (void)pauseSession
{
    if ([self isAppMetricaStartedWithLogging:nil] == NO) { return; }
    if ([AMAMetricaConfiguration sharedInstance].inMemory.sessionsAutoTracking) {
        [AMAErrorLogger logMetricaActivationWithAutomaticSessionsTracking];
        return;
    }
    [[self sharedImpl] pauseSession];
}

+ (void)resumeSession
{
    if ([self isAppMetricaStartedWithLogging:nil] == NO) { return; }
    if ([AMAMetricaConfiguration sharedInstance].inMemory.sessionsAutoTracking) {
        [AMAErrorLogger logMetricaActivationWithAutomaticSessionsTracking];
        return;
    }
    [[self sharedImpl] resumeSession];
}

+ (void)setAccurateLocationTrackingEnabled:(BOOL)enabled
{
    [AMALocationManager sharedManager].accurateLocationEnabled = enabled;
}

+ (BOOL)isAccurateLocationTrackingEnabled
{
    return [AMALocationManager sharedManager].accurateLocationEnabled;
}

+ (void)setAllowsBackgroundLocationUpdates:(BOOL)allowsBackgroundLocationUpdates
{
    [AMALocationManager sharedManager].allowsBackgroundLocationUpdates = allowsBackgroundLocationUpdates;
}

+ (BOOL)allowsBackgroundLocationUpdates
{
    return [AMALocationManager sharedManager].allowsBackgroundLocationUpdates;
}

+ (void)activateReporterWithConfiguration:(AMAReporterConfiguration *)configuration
{
    if ([self isAPIKeyValid:configuration.APIKey] == NO) {
        [AMAErrorLogger logInvalidApiKeyError:configuration.APIKey];
        return;
    }

    @synchronized (self) {
        if ([self isReporterCreatedForAPIKey:configuration.APIKey]) {
            [AMAErrorLogger logMetricaActivationWithAlreadyPresentedKeyError];
        }
        else {
            [[self class] setupExternalServices];
            [[self sharedImpl] activateReporterWithConfiguration:configuration];
        }
    }
}

+ (id<AMAAppMetricaReporting>)reporterForAPIKey:(NSString *)APIKey
{
    return [self extendedReporterForApiKey:APIKey];
}

+ (id<AMAAppMetricaExtendedReporting>)extendedReporterForApiKey:(NSString *)apiKey
{
    if ([self isAPIKeyValid:apiKey] == NO) {
        [AMAErrorLogger logInvalidApiKeyError:apiKey];
        return nil;
    }

    @synchronized (self) {
        if ([self isReporterCreatedForAPIKey:apiKey] == NO) {
            [[AMADataSendingRestrictionController sharedInstance] setReporterRestriction:AMADataSendingRestrictionUndefined
                                                                               forApiKey:apiKey];
        }
        AMAReporterConfiguration *configuration = [[AMAReporterConfiguration alloc] initWithAPIKey:apiKey];
        id<AMAAppMetricaExtendedReporting> reporter = [[self sharedImpl] manualReporterForConfiguration:configuration];
        return reporter;
    }
}

+ (void)requestStartupIdentifiersWithCompletionQueue:(nullable dispatch_queue_t)queue
                                     completionBlock:(AMAIdentifiersCompletionBlock)block
{
    [[self sharedImpl] requestStartupIdentifiersWithCompletionQueue:queue
                                                    completionBlock:block
                                                      notifyOnError:YES];
}

+ (void)requestStartupIdentifiersWithKeys:(NSArray<NSString *> *)keys
                          completionQueue:(nullable dispatch_queue_t)queue
                          completionBlock:(AMAIdentifiersCompletionBlock)block
{
    [[self sharedImpl] requestStartupIdentifiersWithKeys:keys
                                         completionQueue:queue
                                         completionBlock:block
                                           notifyOnError:YES];
}

+ (NSString *)UUID
{
    return [AMAUUIDProvider sharedInstance].retrieveUUID;
}

+ (NSString *)deviceID
{
    NSString *deviceID = nil;
    AMAMetricaConfiguration *configuration = [AMAMetricaConfiguration sharedInstance];
    if (configuration.persistentConfigurationCreated) {
        NSString *currentDeviceID = configuration.persistent.deviceID;
        if (currentDeviceID.length != 0) {
            deviceID = currentDeviceID;
        }
    }
    return deviceID;
}

+ (NSString *)deviceIDHash
{
    NSString *deviceIDHash = nil;
    AMAMetricaConfiguration *configuration = [AMAMetricaConfiguration sharedInstance];
    if (configuration.persistentConfigurationCreated) {
        NSString *currentDeviceIDHash = configuration.persistent.deviceIDHash;
        if (currentDeviceIDHash.length != 0) {
            deviceIDHash = currentDeviceIDHash;
        }
    }
    return deviceIDHash;
}

#pragma mark - Shared -

+ (AMAAppMetricaImpl *)sharedImpl
{
    static AMAAppMetricaImpl *appMetricaImpl = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @autoreleasepool {
            appMetricaImpl = [[AMAAppMetricaImpl alloc] initWithHostStateProvider:self.sharedHostStateProvider
                                                                         executor:self.sharedExecutor];

            [[AMAMetricaConfiguration sharedInstance].inMemory markAppMetricaImplCreated];

            [appMetricaImpl startDispatcher];
        }
    });
    return appMetricaImpl;
}

+ (id<AMAHostStateProviding>)sharedHostStateProvider
{
    static id<AMAHostStateProviding> hostStateProvider = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @autoreleasepool {
            hostStateProvider = [[AMAHostStateProvider alloc] init];
        }
    });
    return hostStateProvider;
}

+ (id<AMAAsyncExecuting, AMASyncExecuting>)sharedExecutor
{
    static id<AMAAsyncExecuting, AMASyncExecuting> executor = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @autoreleasepool {
            executor = [AMAExecutor new];
        }
    });
    return executor;
}

+ (AMAInternalEventsReporter *)sharedInternalEventsReporter
{
    static AMAInternalEventsReporter *reporter = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @autoreleasepool {
            id<AMAAsyncExecuting> executor = [self sharedExecutor];
            id<AMAReporterProviding> reporterProvider =
                [[AMASharedReporterProvider alloc] initWithApiKey:kAMAMetricaLibraryApiKey];
            reporter = [[AMAInternalEventsReporter alloc] initWithExecutor:executor
                                                          reporterProvider:reporterProvider];
        }
    });
    return reporter;
}

+ (AMALogConfigurator *)sharedLogConfigurator
{
    static AMALogConfigurator *logConfigurator = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        @autoreleasepool {
            logConfigurator = [AMALogConfigurator new];
        }
    });
    return logConfigurator;
}

#pragma mark - Private & Testing Availability

+ (NSArray<Class<AMAEventPollingDelegate>> *)eventPollingDelegates
{
    return eventPollingDelegates.allObjects;
}

+ (BOOL)isAppMetricaStartedWithLogging:(void (^)(NSError *))onFailure {
    if ([self isActivated] == NO) {
        [AMAErrorLogger logAppMetricaNotStartedErrorWithOnFailure:onFailure];
        return NO;
    }
    return YES;
}

+ (BOOL)isMetricaImplCreated
{
    @synchronized(self) {
        return [AMAMetricaConfiguration sharedInstance].inMemory.appMetricaImplCreated;
    }
}

+ (NSUInteger)dispatchPeriod
{
    AMAReporterConfiguration *configuration = [[AMAMetricaConfiguration sharedInstance] appConfiguration];
    return configuration.dispatchPeriod;
}

+ (NSUInteger)maxReportsCount
{
    AMAReporterConfiguration *configuration = [[AMAMetricaConfiguration sharedInstance] appConfiguration];
    return configuration.maxReportsCount;
}

+ (NSUInteger)sessionTimeout
{
    return [AMAMetricaConfiguration sharedInstance].appConfiguration.sessionTimeout;
}

+ (void)setBackgroundSessionTimeout:(NSUInteger)sessionTimeoutSeconds
{
    [AMAMetricaConfiguration sharedInstance].inMemory.backgroundSessionTimeout = sessionTimeoutSeconds;
}

+ (NSUInteger)backgroundSessionTimeout
{
    return [AMAMetricaConfiguration sharedInstance].inMemory.backgroundSessionTimeout;
}

@end
