#import "AMAReporter.h"

#import <AppMetricaPlatform/AppMetricaPlatform.h>

#import "AMAReporterNotifications.h"
#import "AMASession.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaInMemoryConfiguration.h"
#import "AMAErrorsFactory.h"
#import "AMAEvent.h"
#import "AMAEventBuilder.h"
#import "AMASessionStorage.h"
#import "AMAEventStorage.h"
#import "AMADate.h"
#import "AMAUserProfile.h"
#import "AMAUserProfileUpdatesProcessor.h"
#import "AMAUserProfileLogger.h"
#import "AMARevenueInfo.h"
#import "AMARevenueInfoProcessor.h"
#import "AMATruncatedDataProcessingResult.h"
#import "AMAEventLogger.h"
#import "AMAEventFirstOccurrenceController.h"
#import "AMAEventNameHashesStorageFactory.h"
#import "AMADataSendingRestrictionController.h"
#import "AMAErrorLogger.h"
#import "AMAAppMetrica.h"
#import "AMAReporterStorage.h"
#import "AMAReporterStateStorage.h"
#import "AMAECommerceTruncator.h"
#import "AMAECommerceSerializer.h"
#import "AMARevenueInfoModel.h"
#import "AMARevenueInfoConverter.h"
#import "AMAAdServicesDataProvider.h"
#import "AMAAttributionController.h"
#import "AMAAttributionChecker.h"
#import "AMAReportRequestProvider.h"
#import "AMAMetricaPersistentConfiguration.h"
#import "AMAAdRevenueInfo.h"
#import "AMAAdRevenueInfoModel.h"
#import "AMAAdRevenueInfoConverter.h"
#import "AMAAdRevenueInfoProcessor.h"
#import "AMAAppMetrica+Internal.h"
#import "AMASessionExpirationHandler.h"
#import "AMAExtrasContainer.h"
#import "AMAAdProvider.h"
#import "AMAPrivacyTimer.h"
#import "AMAPrivacyTimerStorage.h"
#import "AMAExternalAttributionSerializer.h"

@interface AMAReporter () <AMAPrivacyTimerDelegate>

@property (nonatomic, copy) NSString *apiKey;
@property (nonatomic, strong) AMAEventBuilder *eventBuilder;
@property (nonatomic, strong) id<AMACancelableExecuting, AMASyncExecuting> executor;
@property (nonatomic, strong) id<AMAAsyncExecuting> attributionCheckExecutor;
@property (nonatomic, assign) BOOL isActive;
@property (nonatomic, strong) AMAUserProfileUpdatesProcessor *userProfileUpdatesProcessor;
@property (nonatomic, strong) AMARevenueInfoProcessor *revenueInfoProcessor;
@property (nonatomic, strong) AMAAdRevenueInfoProcessor *adRevenueInfoProcessor;
@property (nonatomic, strong) AMAEventFirstOccurrenceController *occurrenceController;
@property (nonatomic, strong, readonly) AMAECommerceSerializer *eCommerceSerializer;
@property (nonatomic, strong, readonly) AMAECommerceTruncator *eCommerceTruncator;
@property (nonatomic, strong, readonly) AMAAdServicesDataProvider *adServices;
@property (nonatomic, strong, readonly) AMASessionExpirationHandler *sessionExpirationHandler;
@property (nonatomic, strong, readonly) AMAExternalAttributionSerializer *externalAttributionSerializer;
@property (nonnull, nonatomic, strong, readonly) AMAAdProvider *adProvider;
@property (nonnull, nonatomic, strong, readonly) AMAPrivacyTimer *privacyTimer;
@property (nonatomic) BOOL isPrivacyTimerStarted;

@end

@implementation AMAReporter

- (instancetype)initWithApiKey:(NSString *)apiKey
                          main:(BOOL)main
               reporterStorage:(AMAReporterStorage *)reporterStorage
                  eventBuilder:(AMAEventBuilder *)eventBuilder
              internalReporter:(AMAInternalEventsReporter *)internalReporter
      attributionCheckExecutor:(id<AMAAsyncExecuting>)attributionCheckExecutor
{
    AMACancelableDelayedExecutor *executor = [[AMACancelableDelayedExecutor alloc] initWithIdentifier:self];
    
    AMAAdProvider *adProvider = [AMAAdProvider sharedInstance];
    
    AMASessionExpirationHandler *sessionExpirationHandler =
        [[AMASessionExpirationHandler alloc] initWithConfiguration:[AMAMetricaConfiguration sharedInstance]
                                                            APIKey:apiKey];
    
    AMAMetrikaPrivacyTimerStorage *timerStorage =
        [[AMAMetrikaPrivacyTimerStorage alloc] initWithReporterMetricaConfiguration:[AMAMetricaConfiguration sharedInstance]
                                                                       stateStorage:reporterStorage.stateStorage];
    AMAPrivacyTimer *privacyTimer = [[AMAPrivacyTimer alloc] initWithTimerStorage:timerStorage
                                                                 delegateExecutor:executor
                                                                       adProvider:adProvider];
    
    AMAAdServicesDataProvider *adServicesDataProvider = nil;
    if (@available(iOS 14.3, *)) {
        adServicesDataProvider = [[AMAAdServicesDataProvider alloc] init];
    }
    
    return [self initWithApiKey:apiKey
                           main:main
                reporterStorage:reporterStorage
                   eventBuilder:eventBuilder
               internalReporter:internalReporter
                       executor:executor
       attributionCheckExecutor:attributionCheckExecutor
            eCommerceSerializer:[[AMAECommerceSerializer alloc] init]
             eCommerceTruncator:[[AMAECommerceTruncator alloc] init]
                     adServices:adServicesDataProvider
  externalAttributionSerializer:[[AMAExternalAttributionSerializer alloc] init]
       sessionExpirationHandler:sessionExpirationHandler
                     adProvider:adProvider
                   privacyTimer:privacyTimer];
}

- (instancetype)initWithApiKey:(NSString *)apiKey
                          main:(BOOL)main
               reporterStorage:(AMAReporterStorage *)reporterStorage
                  eventBuilder:(AMAEventBuilder *)eventBuilder
              internalReporter:(AMAInternalEventsReporter *)internalReporter
                      executor:(id<AMACancelableExecuting, AMASyncExecuting>)executor
      attributionCheckExecutor:(id<AMAAsyncExecuting>)attributionCheckExecutor
           eCommerceSerializer:(AMAECommerceSerializer *)eCommerceSerializer
            eCommerceTruncator:(AMAECommerceTruncator *)eCommerceTruncator
                    adServices:(AMAAdServicesDataProvider *)adServices
 externalAttributionSerializer:(AMAExternalAttributionSerializer *)externalAttributionSerializer
      sessionExpirationHandler:(AMASessionExpirationHandler *)sessionExpirationHandler
                    adProvider:(AMAAdProvider *)adProvider
                  privacyTimer:(AMAPrivacyTimer *)privacyTimer

{
    self = [super init];
    if (self != nil) {
        _apiKey = [apiKey copy];
        _main = main;
        _reporterStorage = reporterStorage;
        _eventBuilder = eventBuilder;
        _executor = executor;
        _internalReporter = internalReporter;
        _userProfileUpdatesProcessor = [[AMAUserProfileUpdatesProcessor alloc] init];
        _revenueInfoProcessor = [[AMARevenueInfoProcessor alloc] init];
        _adRevenueInfoProcessor = [[AMAAdRevenueInfoProcessor alloc] init];
        _attributionCheckExecutor = attributionCheckExecutor;
        _eCommerceSerializer = eCommerceSerializer;
        _eCommerceTruncator = eCommerceTruncator;
        _sessionExpirationHandler = sessionExpirationHandler;
        _externalAttributionSerializer = externalAttributionSerializer;
        _adProvider = adProvider;
        _privacyTimer = privacyTimer;
        privacyTimer.delegate = self;
        
        AMAEventNameHashesStorage *eventHashesStorage = [AMAEventNameHashesStorageFactory storageForApiKey:self.apiKey main:main];
        _occurrenceController = [[AMAEventFirstOccurrenceController alloc] initWithStorage:eventHashesStorage];
        _adServices = adServices;
    }
    return self;
}

- (void)start
{
    [self resumeSession];
}

- (void)restartPrivacyTimer
{
    [self execute:^{
        if (!self.isPrivacyTimerStarted) {
            return;
        }
        
        AMALogInfo(@"restart privacy timer execute %@", self.apiKey);
        [self.privacyTimer stop];
        [self.privacyTimer start];
    }];
}

- (void)setupWithOnStorageRestored:(dispatch_block_t)onStorageRestored
                   onSetupComplete:(dispatch_block_t)onSetupComplete
{
    [self execute:^{
        AMALogInfo(@"Setup reporter: %@", self);
        [self.reporterStorage restoreState];
        if (onStorageRestored != nil) {
            onStorageRestored();
        }
        [self endCurrentSession];
        [self.occurrenceController updateVersion];
        if (onSetupComplete != nil) {
            onSetupComplete();
        }
    }];
}

- (void)shutdown
{
    [self pauseSession];
}

- (void)updateAPIKey:(NSString *)apiKey
{
    @synchronized (self) {
        self.apiKey = apiKey;
    }
}

- (void)setAttributionChecker:(AMAAttributionChecker *)attributionChecker
{
    _attributionChecker = attributionChecker;
    [self.attributionCheckExecutor execute:^{
        BOOL checkedInitialAttribution = [AMAMetricaConfiguration sharedInstance].persistent.checkedInitialAttribution;
        AMALogInfo(@"checked initial attribution ? %d", checkedInitialAttribution);
        if (checkedInitialAttribution == NO) {
            [attributionChecker checkInitialAttribution];
            NSArray<AMAEvent *> *eventsFromDb = [self.reporterStorage.eventStorage allEvents];
            AMALogInfo(@"Check old events. Size: %tu", eventsFromDb.count);
            for (AMAEvent *event in eventsFromDb) {
                [attributionChecker checkSerializedEventAttribution:event];
            }
            [AMAMetricaConfiguration sharedInstance].persistent.checkedInitialAttribution = YES;
        }
    }];
}

#pragma mark - AMAAppMetricaReporting protocol

- (void)resumeSession
{
    [self stampedExecute:^(NSDate *date) {
        [self resumeSessionWithDate:date];
    }];
}

- (void)pauseSession
{
    [self stampedExecute:^(NSDate *date) {
        [self pauseSessionWithDate:date];
    }];
}

- (void)resumeSessionWithDate:(NSDate *)date
{
    AMALogInfo(@"Resuming session of reporter: %@", self.apiKey);
    
    // only when session started
    if (!self.isPrivacyTimerStarted) {
        [self.privacyTimer start];
        self.isPrivacyTimerStarted = YES;
    }
    
    AMASession *currentSession = [self lastSession];
    
    BOOL isSessionBackground = currentSession.type == AMASessionTypeBackground;
    AMASessionExpirationType expirationType = [self.sessionExpirationHandler expirationTypeForSession:currentSession
                                                                                             withDate:date];

    if ([self isSessionFinished:currentSession]) {
        [self createNewSessionWithDate:date];
    }
    else if (isSessionBackground || [self isCurrentSession:currentSession expiredWithType:expirationType]) {
        [self endSession:currentSession updatedAt:nil];
        [self createNewSessionWithDate:date];
    }
    else {
        [self updateStampOfSession:currentSession withDate:date];
    }

    self.isActive = YES;
    [self restartSessionUpdateTimer];
}

- (void)pauseSessionWithDate:(NSDate *)date
{
    AMALogInfo(@"Pausing session of reporter: %@", self);
    
    [self.executor cancelDelayed];

    NSError *error = nil;
    AMASession *currentSession = [self.reporterStorage.sessionStorage lastGeneralSessionWithError:&error];
    AMASessionExpirationType expirationType = [self.sessionExpirationHandler expirationTypeForSession:currentSession
                                                                                             withDate:date];
    if (error != nil) {
        AMALogWarn(@"Failed to fetch last general session");
    }
    if ([self isSessionFinished:currentSession]) {
        // Do nothing. This branch is here just to match 'resumeSessionWithDate:' method.
    }
    else if ([self isCurrentSession:currentSession expiredWithType:expirationType]) {
        [self endSession:currentSession updatedAt:nil];
    }
    else {
        [self updateStampOfSession:currentSession withDate:date];
    }
    
    self.isActive = NO;
}

- (void)createNewSessionWithDate:(NSDate *)date
{
    AMALogInfo(@"Create new session in reporter: %@", self);
    NSError *error = nil;
    AMASession *newSession = [self.reporterStorage.sessionStorage newGeneralSessionCreatedAt:date error:&error];
    if (newSession != nil) {
        [self addStartEventWithDate:date toSession:newSession];
    }
    else {
        AMALogError(@"Failed to create new session: %@", error);
    }
}

- (void)endCurrentSession
{
    AMASession *currentSession = [self lastSession];
    if (currentSession != nil) {
        [self ensureSessionEnded:currentSession];
    }
}

- (void)ensureSessionEnded:(AMASession *)session
{
    if ([self isSessionFinished:session] == NO) {
        [self endSession:session updatedAt:nil];
    }
}

- (void)endSession:(AMASession *)session updatedAt:(NSDate *)date
{
    AMALogInfo(@"End session in reporter: %@", self);
    if (session == nil) {
        AMALogError(@"Failed to end session; No session to end");
        return;
    }
    if (session.finished) {
        AMALogError(@"Failed to end session; Session is finished");
        return;
    }

    AMAEvent *eventAlive = [self.eventBuilder eventAlive];
    NSError *error = nil;
    BOOL success = [self.reporterStorage.sessionStorage finishSession:session atDate:date error:&error];
    if (success) {
        NSDate *endDate = date ?: [self endDateForSession:session];
        NSTimeInterval timeSinceSession = [self timeIntervalSinceSessionStart:session forDate:endDate];
        [self addEvent:eventAlive createdAt:endDate toSession:session timeSince:timeSinceSession];
    }
    else {
        AMALogError(@"Failed to end session: %@", error);
    }
}

- (AMASession *)startNewSessionWithNextAttributionIDForDate:(NSDate *)date error:(NSError **)error
{
    AMALogInfo(@"Create new session with next attribution ID in reporter: %@", self);
    AMASession *currentSession = [self lastSession];
    if ([self isSessionFinished:currentSession] == NO) {
        [self endSession:currentSession updatedAt:date];
    }

    AMASessionType sessionType = AMASessionTypeGeneral;
    if (self.isActive == NO) {
        sessionType = AMASessionTypeBackground;
    }
    AMASession *newSession = [self.reporterStorage.sessionStorage newSessionWithNextAttributionIDCreatedAt:date
                                                                                                      type:sessionType
                                                                                                     error:error];
    if (newSession != nil) {
        [self addStartEventWithDate:date toSession:newSession];
    }
    return newSession;
}

- (void)setDataSendingEnabled:(BOOL)enabled
{
    AMADataSendingRestriction restriction = enabled
        ? AMADataSendingRestrictionAllowed
        : AMADataSendingRestrictionForbidden;
    [[AMADataSendingRestrictionController sharedInstance] setReporterRestriction:restriction forApiKey:self.apiKey];
}

- (void)reportEvent:(NSString *)eventName
         parameters:(NSDictionary *)params
          onFailure:(void (^)(NSError *error))onFailure
{
    [self.attributionChecker checkClientEventAttribution:eventName];
    eventName = [eventName copy];
    params = [params copy];
    [[self logger] logClientEventReceivedWithName:eventName parameters:params];
    [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
        AMAOptionalBool firstOccurrence = [self.occurrenceController isEventNameFirstOccurred:eventName];
        return [self.eventBuilder clientEventNamed:eventName
                                        parameters:params
                                   firstOccurrence:firstOccurrence
                                             error:error];
    }                      onFailure:onFailure];
}

- (void)reportEvent:(NSString *)message onFailure:(void (^)(NSError *error))onFailure
{
    [self reportEvent:message parameters:nil onFailure:onFailure];
}

- (void)reportEventWithType:(NSUInteger)eventType
                       name:(nullable NSString *)name
                      value:(nullable NSString *)value
           eventEnvironment:(nullable NSDictionary *)eventEnvironment
             appEnvironment:(nullable NSDictionary *)appEnvironment
                     extras:(nullable NSDictionary<NSString *, NSData *> *)extras
                  onFailure:(void (^)(NSError *))onFailure
{
    [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
        return [self.eventBuilder eventWithType:eventType
                                           name:name
                                          value:value
                               eventEnvironment:eventEnvironment
                                 appEnvironment:appEnvironment
                                         extras:extras
                                          error:error];
    }
                           onFailure:onFailure];
}

- (void)reportBinaryEventWithType:(NSUInteger)eventType
                             data:(NSData *)data
                             name:(nullable NSString *)name
                          gZipped:(BOOL)gZipped
                 eventEnvironment:(nullable NSDictionary *)eventEnvironment
                   appEnvironment:(nullable NSDictionary *)appEnvironment
                           extras:(nullable NSDictionary<NSString *, NSData *> *)extras
                   bytesTruncated:(NSUInteger)bytesTruncated
                        onFailure:(nullable void (^)(NSError *error))onFailure
{
    [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
        return [self.eventBuilder binaryEventWithType:eventType
                                                 data:data
                                                 name:name
                                              gZipped:gZipped
                                     eventEnvironment:eventEnvironment
                                       appEnvironment:appEnvironment
                                               extras:extras
                                       bytesTruncated:bytesTruncated
                                                error:error];
    }
                           onFailure:onFailure];
}

- (void)reportFileEventWithType:(NSUInteger)eventType
                           data:(NSData *)data
                       fileName:(NSString *)fileName
                        gZipped:(BOOL)gZipped
                      encrypted:(BOOL)encrypted
                      truncated:(BOOL)truncated
               eventEnvironment:(nullable NSDictionary *)eventEnvironment
                 appEnvironment:(nullable NSDictionary *)appEnvironment
                         extras:(nullable NSDictionary<NSString *,NSData *> *)extras
                      onFailure:(void (^)(NSError *))onFailure
{
    [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
        return [self.eventBuilder fileEventWithType:eventType
                                               data:data
                                           fileName:fileName
                                            gZipped:gZipped
                                          encrypted:encrypted
                                          truncated:truncated
                                   eventEnvironment:eventEnvironment
                                     appEnvironment:appEnvironment
                                             extras:extras
                                              error:error];
    }
                           onFailure:onFailure];
}

- (void)setSessionExtras:(nullable NSData *)data forKey:(nonnull NSString *)key
{
    [self execute:^{
        if ([data length] > 0) {
            [self.reporterStorage.stateStorage.extrasContainer addValue:data forKey:key];
        }
        else {
            [self.reporterStorage.stateStorage.extrasContainer removeValueForKey:key];
        }
    }];
}

- (void)clearSessionExtras
{
    [self execute:^{
        [self.reporterStorage.stateStorage.extrasContainer clearExtras];
    }];
}

- (void)reportFirstEventIfNeeded
{
    [self stampedExecute:^(NSDate *date) {
        if (self.reporterStorage.stateStorage.firstEventSent) {
            AMALogInfo(@"First event has already been sent");
            return;
        }

        NSError *error = nil;
        AMAEvent *event = [self.eventBuilder eventFirstWithError:&error];
        if (event == nil) {
            AMALogAssert(@"Failed to report first event; Event reporting failed with error %@", error);
            return;
        }

        AMASession *eventSession = [self currentSessionForEventCreatedAt:date error:&error onNewSession:nil];
        if (eventSession != nil) {
            [self reportEvent:event createdAt:date toSession:eventSession onFailure:nil];
            [self addStartEventWithDate:date toSession:eventSession];
        }
        else {
            AMALogError(@"Failed to report first event, session creation error: %@", error);
        }
        [self.occurrenceController resetHashes];
    }];
}

- (void)reportOpenEvent:(NSDictionary *)parameters
          reattribution:(BOOL)reattribution
              onFailure:(void (^)(NSError *error))onFailure
{
    [self stampedExecute:^(NSDate *date) {
        AMASession *session = nil;
        [self.reporterStorage.stateStorage incrementOpenID];
        if (reattribution) {
            NSError *error = nil;
            session = [self startNewSessionWithNextAttributionIDForDate:date error:&error];
            if (session == nil) {
                AMALogError(@"Failed to create new session for reattribution: %@", error);
            }
            [self.occurrenceController resetHashes];
        }
        [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
            return [self.eventBuilder eventOpen:parameters
                           attributionIDChanged:reattribution
                                          error:error];
        }                        session:session date:date onFailure:onFailure];
    }];
}

- (void)reportCommonEventWithBlock:(AMAEvent *(^)(NSError **error))eventCreationBlock
                         onFailure:(void (^)(NSError *error))onFailure
{
    [self stampedExecute:^(NSDate *date) {
        [self reportCommonEventWithBlock:eventCreationBlock session:nil date:date onFailure:onFailure];
    }];
}

- (void)reportCommonEventWithBlock:(AMAEvent *(^)(NSError **error))eventCreationBlock
                           session:(AMASession *)session
                              date:(NSDate *)date
                         onFailure:(void (^)(NSError *error))onFailure
{
    AMAEvent *event = [self buildEventWithBlock:eventCreationBlock onFailure:onFailure];
    if (event != nil) {
        if (session != nil) {
            [self reportEvent:event createdAt:date toSession:session onFailure:onFailure];
        }
        else {
            [self reportEvent:event createdAt:date onFailure:onFailure];
        }
    }
}

- (AMAEvent *)buildEventWithBlock:(AMAEvent *(^)(NSError **error))eventCreationBlock
                        onFailure:(void (^)(NSError *error))onFailure
{
    NSError *error = nil;
    AMAEvent *event = eventCreationBlock(&error);
    if (event != nil) {
        [[self logger] logEventBuilt:event];
    }
    else {
        [AMAFailureDispatcher dispatchError:error withBlock:onFailure];
        AMALogWarn(@"Failed to report event; Event reporting failed with error %@", error);
    }
    return event;
}

- (void)reportUserProfile:(AMAUserProfile *)userProfile onFailure:(nullable void (^)(NSError *error))onFailure
{
    userProfile = [userProfile copy];
    [[self logger] logProfileEventReceived];
    [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
        AMAEvent *event = nil;
        NSData *userProfileData = [self.userProfileUpdatesProcessor dataWithUpdates:userProfile.updates error:error];
        if (userProfileData != nil) {
            event = [self.eventBuilder eventProfile:userProfileData];
        }
        return event;
    }                      onFailure:onFailure];
}

- (void)reportEmptyUserProfileEventWithDate:(NSDate *)date
{
    [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
        return [self.eventBuilder eventProfile:nil];
    }                        session:nil date:date onFailure:nil];
}

- (AMAEvent *)revenueEventWithModel:(AMARevenueInfoModel *)model error:(NSError **)error
{
    AMAEvent *event = nil;
    AMATruncatedDataProcessingResult *processingResult = [self.revenueInfoProcessor processRevenueModel:model
                                                                                                  error:error];
    if (processingResult != nil) {
        event = [self.eventBuilder eventRevenue:processingResult.data
                                 bytesTruncated:processingResult.bytesTruncated];
    }
    return event;
}

- (AMAEvent *)adRevenueEventWithModel:(AMAAdRevenueInfoModel *)model error:(NSError **)error
{
    AMAEvent *event = nil;
    AMATruncatedDataProcessingResult *processingResult = [self.adRevenueInfoProcessor processAdRevenueModel:model
                                                                                                      error:error];
    if (processingResult != nil) {
        event = [self.eventBuilder eventAdRevenue:processingResult.data
                                   bytesTruncated:processingResult.bytesTruncated];
    }
    return event;
}

- (void)reportRevenue:(AMARevenueInfo *)revenueInfo onFailure:(nullable void (^)(NSError *error))onFailure
{
    revenueInfo = [revenueInfo copy];
    AMARevenueInfoModel *model = [AMARevenueInfoConverter convertRevenueInfo:revenueInfo error:nil];
    [self.attributionChecker checkRevenueEventAttribution:model];
    [[self logger] logRevenueEventReceived];
    [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
        return [self revenueEventWithModel:model error:error];
    } onFailure:onFailure];
}

- (void)reportAutoRevenue:(AMARevenueInfoModel *)revenueInfoModel onFailure:(void (^)(NSError *))onFailure
{
    [self.attributionChecker checkRevenueEventAttribution:revenueInfoModel];
    [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
        return [self revenueEventWithModel:revenueInfoModel error:error];

    } onFailure:onFailure];
}

- (void)reportECommerce:(AMAECommerce *)eCommerce onFailure:(void (^)(NSError *))onFailure
{
    [self.attributionChecker checkECommerceEventAttribution:eCommerce];
    [[self logger] logECommerceEventReceived];
    [self stampedExecute:^(NSDate *date) {
        AMAECommerce *truncatedValue = [self.eCommerceTruncator truncatedECommerce:eCommerce];
        NSArray *results = [self.eCommerceSerializer serializeECommerce:truncatedValue];
        for (AMAECommerceSerializationResult *result in results) {
            [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
                return [self.eventBuilder eventECommerce:result.data
                                          bytesTruncated:result.bytesTruncated];
            }                        session:nil date:date onFailure:onFailure];
        }
    }];
}

- (void)reportAdRevenue:(AMAAdRevenueInfo *)adRevenue onFailure:(void (^)(NSError *error))onFailure
{
    adRevenue = [adRevenue copy];
    NSError *convertationError = nil;
    AMAAdRevenueInfoModel *model = [AMAAdRevenueInfoConverter convertAdRevenueInfo:adRevenue error:&convertationError];
    if (convertationError != nil) {
        AMALogWarn(@"Failed to convert adRevenueInfo: %@", convertationError.localizedDescription);
    }
    [[self logger] logAdRevenueEventReceived];
    [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
        return [self adRevenueEventWithModel:model error:error];
    } onFailure:onFailure];
}

- (void)setUserProfileID:(NSString *)userProfileID
{
    userProfileID = [userProfileID copy];
    [self stampedExecute:^(NSDate *date) {
        NSString *truncatedProfileID =
            [[AMATruncatorsFactory profileIDTruncator] truncatedString:userProfileID
                                                          onTruncation:^(NSUInteger bytesTruncated) {
                                                              [AMAUserProfileLogger logProfileIDTooLong:userProfileID];
                                                          }];
        NSString *oldProfileID = self.reporterStorage.stateStorage.profileID;
        self.reporterStorage.stateStorage.profileID = truncatedProfileID;
        if (truncatedProfileID != oldProfileID && [truncatedProfileID isEqualToString:oldProfileID] == NO) {
            AMALogInfo(@"User profile ID is changed, reporting empty profile event");
            [self reportEmptyUserProfileEventWithDate:date];
        }
    }];
}

- (NSString *)userProfileID
{
    return [self.executor syncExecute:^id {
        return self.reporterStorage.stateStorage.profileID;
    }];
}

- (void)reportPermissionsEventWithPermissions:(NSString *)permissions
                                    onFailure:(void (^)(NSError *error))onFailure
{
    [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
        return [self.eventBuilder permissionsEventWithJSON:permissions error:error];
    }                      onFailure:onFailure];
}

- (void)reportCleanupEvent:(NSDictionary *)parameters onFailure:(void (^)(NSError *error))onFailure
{
    [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
        return [self.eventBuilder eventCleanup:parameters error:error];
    }                      onFailure:onFailure];
}

- (void)reportASATokenEventWithParameters:(NSDictionary *)parameters onFailure:(void (^)(NSError *))onFailure
{
    [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
        return [self.eventBuilder eventASATokenWithParameters:parameters error:error];
    } onFailure:onFailure];
}

#if !TARGET_OS_TV
- (void)setupWebViewReporting:(id<AMAJSControlling>)controller
                    onFailure:(nullable void (^)(NSError *error))onFailure
{
    if ([AMAAppMetrica isActivated] == NO) {
        [AMAErrorLogger logAppMetricaNotStartedErrorWithOnFailure:onFailure];
        return;
    }
    [controller setUpWebViewReporting:self.executor withReporter:self];
}
#endif

- (void)reportExternalAttribution:(NSDictionary *)attribution
                           source:(AMAAttributionSource)source
                        onFailure:(nullable void (^)(NSError *))onFailure 
{
    if (AMAAppMetrica.isActivated == NO) {
        [AMAErrorLogger logAppMetricaNotStartedErrorWithOnFailure:onFailure];
        return;
    }
    [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
        NSData *serialized = [self.externalAttributionSerializer serializeExternalAttribution:attribution
                                                                                       source:source
                                                                                        error:error];
        return [self.eventBuilder eventExternalAttribution:serialized];
    } onFailure:onFailure];
}

#pragma mark - Execution -

- (void)execute:(dispatch_block_t)block
{
    [self.executor execute:block];
}

- (void)stampedExecute:(void (^)(NSDate *date))block
{
    NSDate *date = [NSDate date];
    [self execute:^{
        block(date);
    }];
}

#pragma mark - Events -

- (void)reportEvent:(AMAEvent *)event createdAt:(NSDate *)creationDate onFailure:(void (^)(NSError *))onFailure
{
    NSError *error = nil;
    AMASession *eventSession = [self currentSessionForEventCreatedAt:creationDate
                                                     error:&error
                                              onNewSession:^(AMASession *newSession) {
                                                  [self addStartEventWithDate:creationDate toSession:newSession];
                                              }];
    if (eventSession != nil) {
        [self reportEvent:event createdAt:creationDate toSession:eventSession onFailure:onFailure];
    }
    else {
        AMALogError(@"Failed to create session for event(%@): %@", event, error);
        [AMAFailureDispatcher dispatchError:[AMAErrorsFactory internalInconsistencyError] withBlock:onFailure];
    }
}

- (void)reportEvent:(AMAEvent *)event
          createdAt:(NSDate *)creationDate
          toSession:(AMASession *)eventSession
          onFailure:(void (^)(NSError *))onFailure
{
    if (eventSession == nil) {
        [AMAFailureDispatcher dispatchError:[AMAErrorsFactory sessionNotLoadedError] withBlock:onFailure];
        AMALogError(@"Failed to report event; No loaded session");
        return;
    }
    NSTimeInterval timeSinceSession = [self timeIntervalSinceSessionStart:eventSession forDate:creationDate];
    if (timeSinceSession < 0.f) {
        // TODO: Find a better way to deal with negative interval
        AMALogWarn(@"Time since session start is negative: %f. Event: %@. Session: %@",
                           timeSinceSession, event, eventSession);
        eventSession.startDate.deviceDate = creationDate;
        timeSinceSession = 0.f;
    }
    if ([self addEvent:event createdAt:creationDate toSession:eventSession timeSince:timeSinceSession] == NO) {
        [AMAFailureDispatcher dispatchError:[AMAErrorsFactory internalInconsistencyError] withBlock:onFailure];
    }
}

- (void)reportPastEvent:(AMAEvent *)event
              createdAt:(NSDate *)creationDate
              toSession:(AMASession *)session
              onFailure:(void (^)(NSError *))onFailure
{
    if (session == nil) {
        [AMAFailureDispatcher dispatchError:[AMAErrorsFactory sessionNotLoadedError] withBlock:onFailure];
        AMALogError(@"Failed to report event; No loaded session");
        return;
    }
    NSTimeInterval timeSinceSession = creationDate != nil
        ? [creationDate timeIntervalSinceDate:session.startDate.deviceDate]
        : [self timeIntervalSinceSessionStart:session forDate:[self endDateForSession:session]];
    NSDate *finalCreationDate = creationDate ?: NSDate.date;
    
    if ([self addEvent:event createdAt:finalCreationDate toSession:session timeSince:timeSinceSession] == NO) {
        [AMAFailureDispatcher dispatchError:[AMAErrorsFactory internalInconsistencyError] withBlock:onFailure];
    }
}


#pragma mark - Sessions -

- (AMASession *)lastSession
{
    NSError *error = nil;
    AMASession *eventSession = [self.reporterStorage.sessionStorage lastSessionWithError:&error];
    if (error != nil) {
        AMALogWarn(@"Failed to fetch last session: %@", error);
    }
    return eventSession;
}

- (AMASession *)currentSessionForEventCreatedAt:(NSDate *)creationDate
                                          error:(NSError **)error
                                   onNewSession:(void (^)(AMASession *eventSession))onNewSession
{
    AMASession *currentSession = [self lastSession];
    AMASessionExpirationType expirationType = [self.sessionExpirationHandler expirationTypeForSession:currentSession
                                                                                             withDate:creationDate];
    
    BOOL sessionExpired = [self isCurrentSession:currentSession expiredWithType:expirationType];
    BOOL sessionFinished = [self isSessionFinished:currentSession];
    
    if (sessionExpired || sessionFinished) {
        [self ensureSessionEnded:currentSession];
        currentSession = [self.reporterStorage.sessionStorage newBackgroundSessionCreatedAt:creationDate error:error];
        AMALogInfo(@"Reporter %@ created background session %@", self, currentSession);
        if (onNewSession != nil) {
            onNewSession(currentSession);
        }
    }
    return currentSession;
}

- (AMASession *)finishedSessionForEventCreatedAt:(NSDate *)creationDate
                                        appState:(AMAApplicationState *)appState
                                           error:(NSError **)error
                                    onNewSession:(void (^)(AMASession *eventSession))onNewSession
{
    AMASession *currentSession = [self lastSession];
    if ([self isSessionValid:currentSession forEventCreatedAt:creationDate appState:appState]) {
        AMALogInfo(@"Reporter %@ picked current session <%@> for past event reporting", self, currentSession);
        return currentSession;
    }

    AMASession *previousSession = [self.reporterStorage.sessionStorage previousSessionForSession:currentSession
                                                                                           error:nil];
    if ([self isSessionValid:previousSession forEventCreatedAt:creationDate appState:appState]) {
        AMALogInfo(@"Reporter %@ picked previous session <%@> for past event reporting", self, previousSession);
        return previousSession;
    }

    AMASession *newSession = [self.reporterStorage.sessionStorage newFinishedBackgroundSessionCreatedAt:creationDate
                                                                                               appState:appState
                                                                                                  error:nil];
    AMALogInfo(@"Reporter %@ created new session <%@> for past event reporting", self, newSession);
    if (onNewSession != nil) { onNewSession(newSession); }

    if ([self isSessionFinished:currentSession] == NO) {
        // TODO:(https://nda.ya.ru/t/peuw2IWM6fHZUY) Current session should become last again
        NSError *internalError = nil;
        if ([self.reporterStorage.sessionStorage saveSessionAsLastSession:currentSession error:&internalError]) {
            AMALogInfo(@"Reporter %@ refreshed oid of current active session <%@>", self, currentSession);
        }
        else {
            AMALogError(@"Reporter %@ failed to refresh oid of session <%@>. Error: %@",
                                self, currentSession, internalError);
            [AMAErrorUtilities fillError:error withError:internalError];
        }
    }
    return newSession;
}

- (BOOL)isSessionValid:(AMASession *)session
     forEventCreatedAt:(NSDate *)creationDate
              appState:(AMAApplicationState *)appState
{
    AMASessionExpirationType type = [self.sessionExpirationHandler expirationTypeForSession:session
                                                                                   withDate:creationDate];
    return [self isSessionFinished:session] &&
           type == AMASessionExpirationTypeNone &&
           (appState == nil || [appState isEqual:session.appState]);
}

- (BOOL)isCurrentSession:(AMASession *)currentSession expiredWithType:(AMASessionExpirationType)expirationType
{
    if (expirationType == AMASessionExpirationTypeNone) {
        return NO;
    }
    else if (expirationType == AMASessionExpirationTypeTimeout
        && currentSession.type == AMASessionTypeGeneral
        && self.isActive) {
        return NO;
    }
    return YES;
}

#pragma mark - Events Helpers -

- (void)addStartEventWithDate:(NSDate *)date toSession:(AMASession *)session
{
    AMAEvent *eventStart = [self.eventBuilder eventStartWithData:nil]; //TODO: May be side effects because of `nil`
    [self addEvent:eventStart createdAt:date toSession:session timeSince:0.0];
}

- (BOOL)addEvent:(AMAEvent *)event
       createdAt:(NSDate *)creationDate
       toSession:(AMASession *)session
       timeSince:(NSTimeInterval)timeSinceSession
{
    // Check for init before touch anything db involved
    BOOL shouldReportInitOrUpdateEvent = [self shouldReportEventInitOrEventUpdateWhenSavingEvent:event
                                                                                       toSession:session];

    event.createdAt = creationDate;
    event.timeSinceSession = timeSinceSession;
    event.sessionOid = session.oid;

    NSError *error = nil;
    if ([self.reporterStorage.eventStorage addEvent:event toSession:session error:&error] == NO) {
        AMALogError(@"Failed to save event: %@. Error: %@", event, error);
        return NO;
    }

    [self didAddEvent:event];

    if (shouldReportInitOrUpdateEvent) {
        AMAEvent *additionalEvent = nil;
        if ([AMAMetricaConfiguration sharedInstance].inMemory.handleFirstActivationAsUpdate) {
            additionalEvent = [self.eventBuilder eventUpdateWithError:NULL];
        }
        else {
            additionalEvent = [self.eventBuilder eventInitWithParameters:self.evenInitAdditionalParams error:NULL];
        }
        [self addEvent:additionalEvent createdAt:creationDate toSession:session timeSince:timeSinceSession];
    }
    return YES;
}

- (NSDictionary *)evenInitAdditionalParams
{
    NSMutableDictionary *initAdditionalParams = [NSMutableDictionary dictionaryWithCapacity:1];
    if (@available(iOS 14.3, *)) {
        NSError *error = nil;
        NSString *token = [self.adServices tokenWithError:&error];

        AMAReporter *sdkReporter = (AMAReporter *)[AMAAppMetrica reporterForAPIKey:kAMAMetricaLibraryApiKey];
        if (token != nil) {
            initAdditionalParams[@"asaToken"] = token;
            [sdkReporter reportEvent:@"AppleSearchAdsTokenSuccess" onFailure:nil]; //TODO: Move to proper place
        }
//        else if (error != nil) { //TODO: (Crashes) handle error
//            [sdkReporter reportNSError:error onFailure:nil];
//        }
    }
    return [initAdditionalParams copy];
}

- (void)updateStampOfSession:(AMASession *)session withDate:(NSDate *)date
{
    NSError *error = nil;
    if ([self.reporterStorage.sessionStorage updateSession:session pauseTime:date error:&error]) {
        AMALogInfo(@"Reporter %@ updated timestamp in session %@", self, session);
    }
    else {
        AMALogError(@"Failed to update timestamp in session %@. Error: %@", session, error);
    }
}

- (BOOL)shouldReportEventInitOrEventUpdateWhenSavingEvent:(AMAEvent *)event toSession:(AMASession *)session
{
    BOOL shouldReport = YES;
    shouldReport = shouldReport && event.type == AMAEventTypeStart;
    shouldReport = shouldReport && session.type == AMASessionTypeGeneral;
    if (shouldReport) {
        shouldReport = shouldReport && self.reporterStorage.stateStorage.initEventSent == NO;
        shouldReport = shouldReport && self.reporterStorage.stateStorage.updateEventSent == NO;
    }
    return shouldReport;
}

#pragma mark - Notifications -

// TODO: Try to do it with help of delegate instead of notification. Add dispatchIfNeeded to strategies.
- (void)notifyEventAdded:(AMAEvent *)event
{
    NSNotificationCenter *nc = [NSNotificationCenter defaultCenter];
    [nc postNotificationName:kAMAReporterDidAddEventNotification
                      object:nil
                    userInfo:@{
                        kAMAReporterDidAddEventNotificationUserInfoKeyApiKey : self.apiKey,
                        kAMAReporterDidAddEventNotificationUserInfoKeyEventType : @(event.type)
                    }];
}

- (void)didAddEvent:(AMAEvent *)event
{
    [[self logger] logEventSaved:event];

    switch (event.type) {
        case AMAEventTypeInit:
            [self.reporterStorage.stateStorage markInitEventSent];
            break;
        case AMAEventTypeUpdate:
            [self.reporterStorage.stateStorage markUpdateEventSent];
            break;
        case AMAEventTypeFirst:
            [self.reporterStorage.stateStorage markFirstEventSent];
            break;
    }
    [self notifyEventAdded:event];
}

#pragma mark - Time

- (void)restartSessionUpdateTimer
{
    NSTimeInterval timeout = [AMAMetricaConfiguration sharedInstance].inMemory.updateSessionStampInterval;
    __typeof(self) __weak weakSelf = self;
    [self.executor executeAfterDelay:timeout block:^{
        __typeof(self) strongSelf = weakSelf;
        if (strongSelf.isActive) {
            [strongSelf resumeSessionWithDate:[NSDate date]];
        }
    }];
}

- (BOOL)isSessionFinished:(AMASession *)session
{
    return (session == nil || session.isFinished);
}

- (NSDate *)endDateForSession:(AMASession *)session
{
    NSDate *result = nil;

    if (session.lastEventTime != nil && session.pauseTime != nil) {
        result = [session.lastEventTime laterDate:session.pauseTime];
    }
    else if (session.pauseTime != nil) {
        result = session.pauseTime;
    }
    else if (session.lastEventTime != nil) {
        result = session.lastEventTime;
    }
    else {
        result = session.startDate.deviceDate;
    }

    return result;
}

- (NSTimeInterval)timeIntervalSinceSessionStart:(AMASession *)session forDate:(NSDate *)date
{
    return [date timeIntervalSinceDate:session.startDate.deviceDate];
}

#pragma mark - App Environment

- (void)setAppEnvironmentValue:(NSString *)value forKey:(NSString *)key
{
    [self execute:^{
        [self.reporterStorage.stateStorage.appEnvironment addValue:value forKey:key];
    }];
}

- (void)clearAppEnvironment
{
    [self execute:^{
        [self.reporterStorage.stateStorage.appEnvironment clearEnvironment];
    }];
}

#pragma mark - AMAPrivacyTimerDelegate protocol

- (void)privacyTimerDidFire:(AMAPrivacyTimer *)privacyTimer
{
    BOOL needSent = [self.adProvider isAdvertisingTrackingEnabled] && self.privacyTimer.timerStorage.isResendPeriodOutdated;
    AMALogInfo(@"send privacy event: %@ %d", self.apiKey, needSent);
    if (needSent) {
        NSError *error = nil;
        AMASession *session = [self lastSession];
        AMAApplicationState *newState = [AMAApplicationStateManager applicationState];
        [self.reporterStorage.sessionStorage updateSession:session
                                                  appState:newState
                                                     error:&error];
        
        if (error != nil) {
            AMALogError(@"Failed to update session %@ with appState %@ : %@", session, newState, error);
        }
        
        [self reportEventWithType:AMAEventTypeApplePrivacy
                             name:nil
                            value:nil
                 eventEnvironment:nil
                   appEnvironment:nil
                           extras:nil
                        onFailure:nil];
        [self.privacyTimer.timerStorage privacyEventSent];
    }
}

#pragma mark - Utils

- (AMAEventLogger *)logger
{
    return [AMAEventLogger sharedInstanceForApiKey:self.apiKey];
}

#if AMA_ALLOW_DESCRIPTIONS

- (NSString *)description
{
    NSMutableString *description = [NSMutableString stringWithFormat:@"<%@: ", super.description];
    [description appendFormat:@"apiKey=%@", self.apiKey];
    [description appendString:@">"];
    return description;
}

#endif

- (void)sendEventsBuffer
{
    [self execute:^{
        [self.delegate sendEventsBufferWithApiKey:self.apiKey];
    }];
}

- (void)reportJSEvent:(NSString *)name value:(NSString *)value
{
    [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
        return [self.eventBuilder jsEvent:name
                                    value:value];
    }                      onFailure:nil];
}

- (void)reportJSInitEvent:(NSString *)value
{
    [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
        return [self.eventBuilder jsInitEvent:value];
    }                      onFailure:nil];
}

- (void)reportAttributionEventWithName:(NSString *)name value:(NSDictionary *)value
{
    [self reportCommonEventWithBlock:^AMAEvent *(NSError **error) {
        return [self.eventBuilder attributionEventWithName:name value:value];
    }                      onFailure:nil];
}

@end
