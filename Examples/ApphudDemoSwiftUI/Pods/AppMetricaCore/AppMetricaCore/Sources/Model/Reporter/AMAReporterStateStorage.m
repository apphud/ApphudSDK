
#import "AMAReporterStateStorage+Migration.h"
#import "AMADatabaseProtocol.h"
#import "AMACore.h"
#import "AMAExtrasContainer.h"
#import "AMAModelSerialization.h"
#import "Extras.pb-c.h"
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>

static NSString *const kAMAKeyFirstEventSent = @"session_first_event_sent";
static NSString *const kAMAKeyInitEventSent = @"session_init_event_sent";
static NSString *const kAMAKeyUpdateEventSent = @"session_update_event_sent";
static NSString *const kAMAKeyReferrerEventSent = @"session_referrer_event_sent";
static NSString *const kAMAKeyEmptyReferrerReceived = @"session_referrer_is_empty";

static NSString *const kAMAKeyAppEnvironment = @"app_environment";
static NSString *const kAMAKeyProfileID = @"profile_id";
static NSString *const kAMAKeyLastStateSendDate = @"last_state_send_date";
static NSString *const kAMAKeyExtras = @"extras";

static NSString *const kAMAKeyLastASATokenSendDate = @"last_asa_token_send_date";
static NSString *const kAMAKeyLastPrivacySendDate = @"last_privacy_send_date";

@interface AMAReporterStateStorage ()

@property (nonatomic, strong, readonly) id<AMADatabaseKeyValueStorageProviding> storageProvider;
@property (nonatomic, strong, readonly) id<AMADateProviding> dateProvider;
@property (nonatomic, strong, readonly) AMAIncrementableValueStorage *openIDStorage;

@property (nonatomic, assign, readwrite) BOOL firstEventSent;
@property (nonatomic, assign, readwrite) BOOL initEventSent;
@property (nonatomic, assign, readwrite) BOOL updateEventSent;
@property (nonatomic, assign, readwrite) BOOL referrerEventSent;
@property (nonatomic, assign, readwrite) BOOL emptyReferrerEventSent;
@property (nonatomic, strong, readwrite) AMAEnvironmentContainer *appEnvironment;
@property (nonatomic, strong, readwrite) NSDate *lastStateSendDate;
@property (nonatomic, strong, readwrite) NSDate *lastASATokenSendDate;
@property (atomic, strong, readwrite) NSDate *privacyLastSendDate;
@property (nullable, nonatomic, strong, readwrite) AMAExtrasContainer *extrasContainer;

@end

@implementation AMAReporterStateStorage

@synthesize appEnvironment = _appEnvironment;

- (instancetype)initWithStorageProvider:(id<AMADatabaseKeyValueStorageProviding>)storageProvider
                       eventEnvironment:(AMAEnvironmentContainer *)eventEnvironment
{
    return [self initWithStorageProvider:storageProvider
                        eventEnvironment:eventEnvironment
                            dateProvider:[[AMADateProvider alloc] init]];
}

- (instancetype)initWithStorageProvider:(id<AMADatabaseKeyValueStorageProviding>)storageProvider
                       eventEnvironment:(AMAEnvironmentContainer *)eventEnvironment
                           dateProvider:(id<AMADateProviding>)dateProvider
{
    self = [super init];
    if (self != nil) {
        _storageProvider = storageProvider;
        [_storageProvider addBackingKeys:self.criticalKeys];

        _eventEnvironment = eventEnvironment;
        _dateProvider = dateProvider;
        _sessionIDStorage = [AMAIncrementableValueStorageFactory lastSessionIDStorage];
        _attributionIDStorage = [AMAIncrementableValueStorageFactory attributionIDStorage];
        _openIDStorage = [AMAIncrementableValueStorageFactory openIDStorage];
        _requestIDStorage = [AMAIncrementableValueStorageFactory requestIdentifierStorage];
    }
    return self;
}

- (NSArray<NSString *> *)commonKeys
{
    return @[
        kAMAKeyFirstEventSent,
        kAMAKeyInitEventSent,
        kAMAKeyUpdateEventSent,
        kAMAKeyReferrerEventSent,
        kAMAKeyEmptyReferrerReceived,
        kAMAKeyAppEnvironment,
        kAMAKeyProfileID,
    ];
}

- (NSArray<NSString *> *)restoreStateKeys
{
    return [self.commonKeys arrayByAddingObjectsFromArray:@[
        self.sessionIDStorage.key,
        self.attributionIDStorage.key,
        self.requestIDStorage.key,
        self.openIDStorage.key,
        kAMAKeyLastStateSendDate,
        kAMAKeyLastASATokenSendDate,
        kAMAKeyExtras,
        kAMAKeyLastPrivacySendDate,
    ]];
}

- (NSArray<NSString *> *)criticalKeys
{
    return [self.commonKeys arrayByAddingObjectsFromArray:@[
        kAMAAttributionIDStorageKey,
        kAMALastSessionIDStorageKey,
        kAMAGlobalEventNumberStorageKey,
        kAMARequestIdentifierStorageKey,
        kAMAOpenIDStorageKey,
        kAMAKeyExtras,
    ]];
}

- (void)restoreState
{
    NSArray *keys = self.restoreStateKeys;
    id<AMAReadonlyKeyValueStoring> loadedStorage = [self.storageProvider nonPersistentStorageForKeys:keys error:nil];

    AMALogInfo(@"Reporter state for %@: %@", self, loadedStorage);

    self.firstEventSent = [loadedStorage boolNumberForKey:kAMAKeyFirstEventSent error:nil].boolValue;
    self.initEventSent = [loadedStorage boolNumberForKey:kAMAKeyInitEventSent error:nil].boolValue;
    self.updateEventSent = [loadedStorage boolNumberForKey:kAMAKeyUpdateEventSent error:nil].boolValue;
    self.referrerEventSent = [loadedStorage boolNumberForKey:kAMAKeyReferrerEventSent error:nil].boolValue;
    self.emptyReferrerEventSent = [loadedStorage boolNumberForKey:kAMAKeyEmptyReferrerReceived error:nil].boolValue;

    [self.sessionIDStorage restoreFromStorage:loadedStorage];
    [self.attributionIDStorage restoreFromStorage:loadedStorage];
    [self.requestIDStorage restoreFromStorage:loadedStorage];
    [self.openIDStorage restoreFromStorage:loadedStorage];

    self.appEnvironment = [self restoreEnvironmentFromStorage:loadedStorage];
    if (self.appEnvironment != nil) {
        [self.appEnvironment addObserver:self
                               withBlock:^(AMAReporterStateStorage *observer, AMAEnvironmentContainer *environment) {
                                   [observer syncEnvironmentContainer:environment];
                               }];
    }
    self.extrasContainer = [self restoreExtrasFromStorage:loadedStorage];
    [self.extrasContainer addObserver:self
                            withBlock:^(AMAReporterStateStorage *observer, AMAExtrasContainer *extras) {
                                [observer syncExtrasContainer:extras];
                            }];
    
    _profileID = [loadedStorage stringForKey:kAMAKeyProfileID error:nil];

    self.lastStateSendDate = [loadedStorage dateForKey:kAMAKeyLastStateSendDate error:nil] ?: [NSDate distantPast];
    self.lastASATokenSendDate = [loadedStorage dateForKey:kAMAKeyLastASATokenSendDate error:NULL] ?: [NSDate distantPast];
    self.privacyLastSendDate = [loadedStorage dateForKey:kAMAKeyLastPrivacySendDate error:nil] ?: [NSDate distantPast];
}

- (void)markFirstEventSent
{
    if (self.firstEventSent == NO) {
        self.firstEventSent = YES;
        [self saveTrueForKey:kAMAKeyFirstEventSent];
    }
}

- (void)markInitEventSent
{
    if (self.initEventSent == NO) {
        self.initEventSent = YES;
        [self saveTrueForKey:kAMAKeyInitEventSent];
    }
}

- (void)markUpdateEventSent
{
    if (self.updateEventSent == NO) {
        self.updateEventSent = YES;
        [self saveTrueForKey:kAMAKeyUpdateEventSent];
    }
}

- (void)markReferrerEventSent
{
    if (self.referrerEventSent == NO) {
        self.referrerEventSent = YES;
        [self saveTrueForKey:kAMAKeyReferrerEventSent];
    }
}

- (void)markEmptyReferrerEventSent
{
    if (self.emptyReferrerEventSent == NO) {
        self.emptyReferrerEventSent = YES;
        [self saveTrueForKey:kAMAKeyEmptyReferrerReceived];
    }
}

- (BOOL)saveTrueForKey:(NSString *)key
{
    return [self.storageProvider.syncStorage saveBoolNumber:@YES forKey:key error:nil];
}

- (void)setProfileID:(NSString *)profileID
{
    if ([_profileID isEqual:profileID] == NO) {
        _profileID = [profileID copy];
        [self.storageProvider.syncStorage saveString:profileID forKey:kAMAKeyProfileID error:nil];
    }
}

- (void)markStateSentNow
{
    self.lastStateSendDate = [self updateToCurrentDateWithKey:kAMAKeyLastStateSendDate];
}

- (void)markASATokenSentNow
{
    self.lastASATokenSendDate = [self updateToCurrentDateWithKey:kAMAKeyLastASATokenSendDate];
}

- (NSUInteger)openID
{
    return [[self.openIDStorage valueWithStorage:self.storageProvider.syncStorage] unsignedLongValue];
}

- (void)incrementOpenID
{
    NSError *error = nil;
    [self.openIDStorage nextInStorage:self.storageProvider.syncStorage
                             rollback:nil
                                error:&error];
    if (error != nil) {
        AMALogWarn(@"Could not increment open id. Error: %@", error);
    }
}

- (void)markLastPrivacySentNow
{
    self.privacyLastSendDate = [self updateToCurrentDateWithKey:kAMAKeyLastPrivacySendDate];
}

- (NSDate *)updateToCurrentDateWithKey:(NSString *)key
{
    NSDate *date = self.dateProvider.currentDate;
    [self.storageProvider.syncStorage saveDate:date forKey:key error:nil];
    return date;
}

#pragma mark - App Environment Sync

- (AMAEnvironmentContainer *)restoreEnvironmentFromStorage:(id<AMAReadonlyKeyValueStoring>)storage
{
    NSString *stringEnvironment = [storage stringForKey:kAMAKeyAppEnvironment error:nil];
    NSError *error = nil;
    NSDictionary *dictionaryEnvironment = [AMAJSONSerialization dictionaryWithJSONString:stringEnvironment
                                                                                   error:&error];

    AMAEnvironmentContainer *container =
        [[AMAEnvironmentContainer alloc] initWithDictionaryEnvironment:dictionaryEnvironment];
    return container;
}

- (AMAExtrasContainer *)restoreExtrasFromStorage:(id<AMAReadonlyKeyValueStoring>)storage
{
    NSData *extrasData = [storage dataForKey:kAMAKeyExtras error:nil];

    NS_VALID_UNTIL_END_OF_SCOPE AMAProtobufAllocator *allocator = [[AMAProtobufAllocator alloc] init];
    Ama__Extras *protoExtras = ama__extras__unpack(allocator.protobufCAllocator, extrasData.length, extrasData.bytes);
    if (protoExtras == NULL) {
        [AMAErrorUtilities fillError:nil withInternalErrorName:@"Extras is not a valid protobuf"];
        return nil;
    }

    NSDictionary<NSString *, NSData *> *extras = [AMAModelSerialization extrasFromProtobuf:protoExtras];
    AMAExtrasContainer *container = [AMAExtrasContainer containerWithDictionary:extras];
    return container;
}

- (void)syncEnvironmentContainer:(AMAEnvironmentContainer *)environmentContainer
{
    NSDictionary *dictionaryEnvironment = environmentContainer.dictionaryEnvironment;
    NSString *stringEnvironment = @"";

    if (dictionaryEnvironment.count != 0) {
        stringEnvironment = [AMAJSONSerialization stringWithJSONObject:dictionaryEnvironment error:nil] ?: @"";
    }

    [self.storageProvider.syncStorage saveString:stringEnvironment forKey:kAMAKeyAppEnvironment error:nil];
}

- (void)syncExtrasContainer:(AMAExtrasContainer *)extrasContainer
{
    NSData *__block data = nil;
    [AMAAllocationsTrackerProvider track:^(id<AMAAllocationsTracking> tracker) {
        Ama__Extras protoExtras;
        ama__extras__init(&protoExtras);

        (void)[AMAModelSerialization fillExtrasData:&protoExtras
                                     withDictionary:extrasContainer.dictionaryExtras
                                            tracker:tracker];

        size_t dataSize = ama__extras__get_packed_size(&protoExtras);
        uint8_t *dataBytes = malloc(dataSize);
        ama__extras__pack(&protoExtras, dataBytes);
        data = [NSData dataWithBytesNoCopy:dataBytes length:dataSize];
    }];

    [self.storageProvider.syncStorage saveData:data forKey:kAMAKeyExtras error:nil];
}

#pragma mark - Migration

- (void)updateAppEnvironmentJSON:(NSString *)json
{
    [self.storageProvider.syncStorage saveString:json forKey:kAMAKeyAppEnvironment error:nil];
    NSDictionary *dictionaryEnvironment = [AMAJSONSerialization dictionaryWithJSONString:json error:nil];
    self.appEnvironment = [[AMAEnvironmentContainer alloc] initWithDictionaryEnvironment:dictionaryEnvironment];
}

- (void)updateLastStateSendDate:(NSDate *)date
{
    [self.storageProvider.syncStorage saveDate:date forKey:kAMAKeyLastStateSendDate error:nil];
    self.lastStateSendDate = date;
}

@end
