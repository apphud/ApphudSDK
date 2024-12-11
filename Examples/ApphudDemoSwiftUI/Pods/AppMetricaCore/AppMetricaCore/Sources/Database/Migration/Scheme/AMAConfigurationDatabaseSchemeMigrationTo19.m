
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMAConfigurationDatabaseSchemeMigrationTo19.h"
#import "AMAReporterStoragesContainer.h"
#import "AMAReporterStorage.h"
#import "AMADatabaseProtocol.h"
#import "AMAReporterStateStorage+Migration.h"
#import "AMASessionStorage+Migration.h"
#import "AMAEventStorage+Migration.h"
#import "AMADate.h"
#import "AMAEvent.h"
#import "AMAFileEventValue.h"
#import "AMABinaryEventValue.h"
#import "AMAStringEventValue.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>
#import <CoreLocation/CoreLocation.h>

static NSUInteger const kAMAAPIKeyStringLength = 36;

static NSTimeInterval AMAStorageTimeIntervalFromString(NSString *string)
{
    return [string doubleValue];
}

static NSDate *AMAStorageDateFromString(NSString *string)
{
    if (string.length == 0) {
        return nil;
    }
    return [NSDate dateWithTimeIntervalSince1970:AMAStorageTimeIntervalFromString(string)];
}

static NSNumber *AMAStorageUnsignedLongLongFromString(NSString *string)
{
    return [NSNumber numberWithUnsignedLongLong:(unsigned long long)[string longLongValue]];
}

@implementation AMAConfigurationDatabaseSchemeMigrationTo19

- (NSUInteger)schemeVersion
{
    return 19;
}

- (BOOL)applyTransactionalMigrationToDatabase:(AMAFMDatabase *)db
{
    BOOL success = YES;
    NSArray *allKeys = [self allKeyValueStorageKeysForDatabase:db];
    NSArray *allApiKeys = [self apiKeysForDatabase:db allKeys:allKeys];
    NSMutableArray *legacyKVKeys = [NSMutableArray array];

    AMAReporterStoragesContainer *container = [AMAReporterStoragesContainer sharedInstance];
    for (NSString *apiKey in allApiKeys) {
        [self migrateKeyValueStorageFromDatabase:db
                                 reporterStorage:[container storageForApiKey:apiKey]
                                      legacyKeys:legacyKVKeys];
    }
    for (NSString *apiKey in allApiKeys) {
        [self migrateSessionsFromDatabase:db reporterStorage:[container storageForApiKey:apiKey]];
        [container completeMigrationForApiKey:apiKey];
    }
    [self cleanupWithDatabase:db legacyKVKeys:legacyKVKeys];
    return success;
}

- (NSArray *)allKeyValueStorageKeysForDatabase:(AMAFMDatabase *)db
{
    NSMutableArray *keys = [NSMutableArray array];
    AMAFMResultSet *rs = [db executeQuery:@"SELECT k FROM kv"];
    while ([rs next]) {
        NSString *key = [[rs stringForColumnIndex:0] copy];
        if (key != nil && [key isKindOfClass:[NSString class]]) {
            [keys addObject:key];
        }
    }
    [rs close];
    return [keys copy];
}

- (NSArray *)apiKeysForDatabase:(AMAFMDatabase *)db allKeys:(NSArray *)allKeys
{
    NSMutableSet *apiKeys = [NSMutableSet set];
    [apiKeys unionSet:[self sessionsApiKeysForDatabase:db]];
    [apiKeys unionSet:[self keyValueApiKeysForKeys:allKeys]];
    return [apiKeys allObjects];
}

- (NSSet *)sessionsApiKeysForDatabase:(AMAFMDatabase *)db
{
    NSMutableSet *apiKeys = [NSMutableSet set];
    NSDictionary *sharedReporterKeys = [[self class] defaultSharedReportersKeyPairs];
    AMAFMResultSet *rs = [db executeQuery:@"SELECT DISTINCT api_key FROM sessions"];
    while ([rs next]) {
        NSString *key = [[rs stringForColumnIndex:0] copy];
        if (key != nil && [key isKindOfClass:[NSString class]]) {
            if ([AMAIdentifierValidator isValidUUIDKey:key]) {
                [apiKeys addObject:key];
            }
            else if ([AMAIdentifierValidator isValidNumericKey:key]) {
                NSString *newApiKey = sharedReporterKeys[key];
                if (newApiKey != nil) {
                    [apiKeys addObject:newApiKey];
                }
            }
            else {
                // We drop all unknown numeric keys
            }
        }
    }
    [rs close];
    return apiKeys;
}

- (NSSet *)keyValueApiKeysForKeys:(NSArray *)allKeys
{
    NSMutableSet *apiKeys = [NSMutableSet set];
    NSArray *suffixes = @[
        @"session_init_event_sent",
        @"session_first_event_sent",
    ];
    for (NSString *key in allKeys) {
        for (NSString *suffix in suffixes) {
            if (key.length == kAMAAPIKeyStringLength + suffix.length && [key hasSuffix:suffix]) {
                [apiKeys addObject:[key substringWithRange:NSMakeRange(0, kAMAAPIKeyStringLength)]];
            }
        }
    }
    return apiKeys;
}

+ (NSDictionary *)defaultSharedReportersKeyPairs
{
    return @{
        @"13" : @"20799a27-fa80-4b36-b2db-0f8141f24180", // AppMetrica Production
        @"21952" : @"4e610cd2-753f-4bfc-9b05-772ce8905c5e", // AppMetrica Testing
        @"22678" : @"e4250327-8d3c-4d35-b9e8-3c1720a64b91", // AM Testing
        @"22675" : @"67bb016b-be40-4c08-a190-96a3f3b503d3", // AM Production
#ifdef DEBUG
        @"1111" : @"550e8400-e29b-41d4-a716-446655440000", // Unit tests
#endif
    };
}

+ (NSDictionary *)reverseDefaultSharedReportersKeyPairs
{
    static NSDictionary *pairs = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        NSMutableDictionary *reversePairs = [NSMutableDictionary dictionary];
        [[[self class] defaultSharedReportersKeyPairs] enumerateKeysAndObjectsUsingBlock:^(NSString *numeric, NSString *uid, BOOL *stop) {
            reversePairs[uid] = numeric;
        }];
        pairs = [reversePairs copy];
    });
    return pairs;
}

#pragma mark - KV migration

- (BOOL)migrateKeyValueStorageFromDatabase:(AMAFMDatabase *)sourceDB
                           reporterStorage:(AMAReporterStorage *)storage
                                legacyKeys:(NSMutableArray *)legacyKeys
{
    NSString *apiKey = storage.apiKey;
    AMAReporterStateStorage *state = storage.stateStorage;
    NSDictionary<NSString *, NSString *> *keyValues = [self dictionaryForKeysWithApiKey:apiKey db:sourceDB];
    [self migrateMetaSessionInfoForApiKey:apiKey keyValues:keyValues state:state];
    [self migrateIncremenableValuesForApiKey:apiKey keyValues:keyValues state:state storage:storage];
    [self migrateEventNumbersFromKeyValues:keyValues storage:storage];
    [self migrateOtherValuesForApiKey:apiKey keyValues:keyValues state:state];
    [legacyKeys addObjectsFromArray:keyValues.allKeys];
    return YES;
}

- (NSDictionary *)dictionaryForKeysWithApiKey:(NSString *)apiKey db:(AMAFMDatabase *)db
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    NSString *likeValue = [NSString stringWithFormat:@"%@%@%@", @"%", apiKey, @"%"];
    AMAFMResultSet *rs = [db executeQuery:@"SELECT k, v FROM kv WHERE k LIKE ?" values:@[ likeValue ] error:nil];
    while ([rs next]) {
        NSString *key = [[rs stringForColumnIndex:0] copy];
        NSString *value = [[rs stringForColumnIndex:1] copy];
        if (key != nil && [key isKindOfClass:[NSString class]]) {
            dictionary[key] = value;
        }
    }
    [rs close];
    return [dictionary copy];
}

- (void)migrateMetaSessionInfoForApiKey:(NSString *)apiKey
                              keyValues:(NSDictionary<NSString *,NSString *> *)keyValues
                                  state:(AMAReporterStateStorage *)state
{
    BOOL hasFirst = [self metaSessionValueForKey:@"session_first_event_sent" apiKey:apiKey keyValues:keyValues];
    if (hasFirst) {
        [state markFirstEventSent];
    }
    if ([self metaSessionValueForKey:@"session_init_event_sent" apiKey:apiKey keyValues:keyValues]) {
        [state markInitEventSent];

        // Migration for pre-first-event storage that was in AMAStorageDataMigrationFromOldInit
        if (hasFirst == NO) {
            [state markFirstEventSent];
        }
    }
    if ([self metaSessionValueForKey:@"session_update_event_sent" apiKey:apiKey keyValues:keyValues]) {
        [state markUpdateEventSent];
    }
#pragma clang diagnostic push
#pragma clang diagnostic ignored "-Wdeprecated-declarations"
    if ([self metaSessionValueForKey:@"session_referrer_event_sent" apiKey:apiKey keyValues:keyValues]) {
        [state markReferrerEventSent];
    }
    if ([self metaSessionValueForKey:@"session_referrer_is_empty" apiKey:apiKey keyValues:keyValues]) {
        [state markEmptyReferrerEventSent];
    }
#pragma clang diagnostic pop
}

- (BOOL)metaSessionValueForKey:(NSString *)key apiKey:(NSString *)apiKey keyValues:(NSDictionary *)keyValues
{
    return [keyValues[[NSString stringWithFormat:@"%@%@", apiKey, key]] isEqualToString:@"YES"];
}

- (void)migrateIncremenableValuesForApiKey:(NSString *)apiKey
                                 keyValues:(NSDictionary *)keyValues
                                     state:(AMAReporterStateStorage *)state
                                   storage:(AMAReporterStorage *)storage
{
    [storage storageInDatabase:^(id<AMAKeyValueStoring>  _Nonnull storage) {
        NSNumber *sessionID = [self incremenableStorageNumberForKey:@"sessions"
                                                             apiKey:apiKey
                                                          keyValues:keyValues];
        if (sessionID != nil) {
            [state.sessionIDStorage updateValue:sessionID storage:storage error:nil];
        }
        NSNumber *attributionID = [self incremenableStorageNumberForKey:@"attribution.id"
                                                                 apiKey:apiKey
                                                              keyValues:keyValues];
        if (attributionID != nil) {
            [state.attributionIDStorage updateValue:attributionID storage:storage error:nil];
        }

        NSNumber *requestID = [self incremenableStorageNumberForKey:@"request.identifier"
                                                             apiKey:apiKey
                                                          keyValues:keyValues];
        if (requestID != nil) {
            [state.requestIDStorage updateValue:requestID storage:storage error:nil];
        }
    }];
}

- (NSNumber *)incremenableStorageNumberForKey:(NSString *)key
                                       apiKey:(NSString *)apiKey
                                    keyValues:(NSDictionary *)keyValues
{
    NSString *stringValue = keyValues[[NSString stringWithFormat:@"com.yandex.mobile.appmetrica.%@.%@", key, apiKey]];
    return stringValue.length != 0 ? [NSNumber numberWithLongLong:stringValue.longLongValue] : nil;
}

- (void)migrateEventNumbersFromKeyValues:(NSDictionary<NSString *,NSString *> *)keyValues
                                 storage:(AMAReporterStorage *)storage
{
    NSString *const commonPrefix = @"com.yandex.mobile.appmetrica.";
    NSString *const eventNumberPrefix = [NSString stringWithFormat:@"%@event.number", commonPrefix];
    NSUInteger const commonPrefixLength = commonPrefix.length;
    id<AMAKeyValueStoring> values = [storage.keyValueStorageProvider emptyNonPersistentStorage];
    [keyValues enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        if ([key hasPrefix:eventNumberPrefix]) {
            NSRange range =
                NSMakeRange(commonPrefixLength, key.length - commonPrefixLength - kAMAAPIKeyStringLength - 1);
            NSString *migratedKey = [key substringWithRange:range];
            NSNumber *numberValue = AMAStorageUnsignedLongLongFromString(value);
            [values saveLongLongNumber:numberValue forKey:migratedKey error:nil];
        }
    }];
    [storage.keyValueStorageProvider saveStorage:values error:nil];
}

- (void)migrateOtherValuesForApiKey:(NSString *)apiKey
                          keyValues:(NSDictionary *)keyValues
                              state:(AMAReporterStateStorage *)state
{
    NSString *profileID = keyValues[[NSString stringWithFormat:@"com.yandex.mobile.appmetrica.profileid.%@", apiKey]];
    if (profileID.length != 0) {
        state.profileID = profileID;
    }
    NSString *appEnvironmentString =
        keyValues[[NSString stringWithFormat:@"com.yandex.mobile.appmetrica.appenvironment.%@", apiKey]];
    if (appEnvironmentString.length != 0) {
        [state updateAppEnvironmentJSON:appEnvironmentString];
    }
}

#pragma mark - Events and sessions migration

- (void)migrateSessionsFromDatabase:(AMAFMDatabase *)sourceDB
                    reporterStorage:(AMAReporterStorage *)storage
{
    NSArray *sessions = [self sessionsForApiKey:storage.apiKey db:sourceDB];
    for (AMASession *session in sessions) {
        NSNumber *sourceSessionOID  = session.oid;
        AMALogInfo(@"Migrating session of '%@': %@", storage.apiKey, session);
        session.oid = nil;
        if ([storage.sessionStorage addMigratedSession:session error:nil]) {
            [self migrateEventsForSourceSessionOID:sourceSessionOID
                                  targetSessionOID:session.oid
                                                db:sourceDB
                                   reporterStorage:storage];
        }
        else {
            AMALogError(@"Failed to migrate session: %@", session);
        }
    }
}

- (void)migrateEventsForSourceSessionOID:(NSNumber *)sourceSessionOID
                        targetSessionOID:(NSNumber *)targetSessionOID
                                      db:(AMAFMDatabase *)sourceDB
                         reporterStorage:(AMAReporterStorage *)storage
{
    AMAFMResultSet *rs = [sourceDB executeQuery:@"SELECT * FROM events WHERE session_id = ? ORDER BY id ASC"
                                      values:@[ sourceSessionOID ]
                                       error:nil];
    while ([rs next]) {
        AMAEvent *event = [self eventForResultSet:rs];
        AMALogInfo(@"Migrating event of '%@': %@", storage.apiKey, event);
        event.oid = nil;
        event.sessionOid = targetSessionOID;
        if (event != nil) {
            [storage.eventStorage addMigratedEvent:event error:nil];
        }
        else {
            AMALogError(@"Failed to create event from resultSet: %@", rs.resultDictionary);
        }
    }
    [rs close];
}

- (NSArray<AMASession *> *)sessionsForApiKey:(NSString *)apiKey db:(AMAFMDatabase *)db
{
    NSMutableArray *sessions = [NSMutableArray array];
    NSString *additionalApiKey = [[self class] reverseDefaultSharedReportersKeyPairs][apiKey] ?: apiKey;
    AMAFMResultSet *rs = [db executeQuery:@"SELECT * FROM sessions WHERE api_key IN (?, ?) ORDER BY id ASC"
                                values:@[ apiKey, additionalApiKey ]
                                 error:nil];
    while ([rs next]) {
        AMASession *session = [self sessionForResultSet:rs];
        if (session != nil) {
            [sessions addObject:session];
        }
        else {
            AMALogError(@"Failed to create session from resultSet: %@", rs.resultDictionary);
        }
    }
    [rs close];
    return [sessions copy];
}

- (AMASession *)sessionForResultSet:(AMAFMResultSet *)rs
{
    AMASession *session = [[AMASession alloc] init];
    session.startDate = [[AMADate alloc] init];

    session.oid = @([rs intForColumn:@"id"]);
    session.startDate.deviceDate = AMAStorageDateFromString([rs stringForColumn:@"start_time"]);
    session.lastEventTime = AMAStorageDateFromString([rs stringForColumn:@"last_event_time"]);
    session.pauseTime = AMAStorageDateFromString([rs stringForColumn:@"pause_time"]);
    session.eventSeq = (NSUInteger)[rs intForColumn:@"event_seq"];
    session.type = (AMASessionType)[rs intForColumn:@"type"];
    session.finished = [rs boolForColumn:@"finished"];
    session.sessionID = AMAStorageUnsignedLongLongFromString([rs stringForColumn:@"session_id"]);

    if ([rs columnIsNull:@"attribution_id"] == NO) {
        session.attributionID = [rs stringForColumn:@"attribution_id"];
    }
    if ([rs columnIsNull:@"server_time_offset"] == NO) {
        session.startDate.serverTimeOffset = @([rs doubleForColumn:@"server_time_offset"]);
    }
    if ([rs columnIsNull:@"app_state"] == NO) {
        NSString *storedAppState = [rs stringForColumn:@"app_state"];
        NSDictionary *appStateDictionary = [AMAJSONSerialization dictionaryWithJSONString:storedAppState error:nil];
        session.appState = [AMAApplicationState objectWithDictionaryRepresentation:appStateDictionary];
    }
    return session;
}

- (CLLocation *)locationForResultSet:(AMAFMResultSet *)rs
{
    if ([rs columnIsNull:@"latitude"] || [rs columnIsNull:@"longitude"]) {
        return nil;
    }

    CLLocationDegrees lat = [rs doubleForColumn:@"latitude"];
    CLLocationDegrees lon = [rs doubleForColumn:@"longitude"];
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(lat, lon);
    NSDate *locationTimestamp = AMAStorageDateFromString([rs stringForColumn:@"location_timestamp"]);
    double course = [rs doubleForColumn:@"location_direction"];
    double speed = [rs doubleForColumn:@"location_speed"];
    double horizontalAccuracy = [rs doubleForColumn:@"location_horizontal_accuracy"];
    double verticalAccuracy = [rs doubleForColumn:@"location_vertical_accuracy"];
    double altitude = [rs doubleForColumn:@"location_altitude"];
    return [[CLLocation alloc] initWithCoordinate:coordinate
                                         altitude:altitude
                               horizontalAccuracy:horizontalAccuracy
                                 verticalAccuracy:verticalAccuracy
                                           course:course
                                            speed:speed
                                        timestamp:locationTimestamp];
}

- (AMAEvent *)eventForResultSet:(AMAFMResultSet *)rs
{
    AMAEvent *event = [[AMAEvent alloc] init];
    event.oid = @([rs intForColumn:@"id"]);
    event.createdAt = AMAStorageDateFromString([rs stringForColumn:@"created_at"]);
    event.sessionOid = @([rs intForColumn:@"session_id"]);
    event.sequenceNumber = (NSUInteger)[rs intForColumn:@"seq"];
    event.globalNumber = (NSUInteger)[rs intForColumn:@"global_number"];
    event.numberOfType = (NSUInteger)[rs intForColumn:@"number_of_type"];
    event.timeSinceSession = AMAStorageTimeIntervalFromString([rs stringForColumn:@"offset"]);
    event.name = [rs stringForColumn:@"name"];
    event.type = (NSUInteger)[rs intForColumn:@"type"];
    event.value = [self eventValueForResultSet:rs eventType:event.type];
    event.bytesTruncated = (NSUInteger)[rs intForColumn:@"bytes_truncated"];
    event.locationEnabled = (AMAOptionalBool)[rs intForColumn:@"location_enabled"];
    event.profileID = [rs stringForColumn:@"user_profile_id"];
    event.firstOccurrence = (AMAOptionalBool)[rs intForColumn:@"first_occurrence"];

    event.location = [self locationForResultSet:rs];

    NSError *error = nil;
    NSString *appEnvironmentString = [rs stringForColumn:@"app_environment"];
    event.appEnvironment = [AMAJSONSerialization dictionaryWithJSONString:appEnvironmentString error:&error];

    error = nil;
    NSString *errorEnvironmentString = [rs stringForColumn:@"error_environment"];
    event.eventEnvironment = [AMAJSONSerialization dictionaryWithJSONString:errorEnvironmentString error:&error];

    return event;
}

- (id<AMAEventValueProtocol>)eventValueForResultSet:(AMAFMResultSet *)rs eventType:(NSUInteger)eventType
{
    NSString *value = [rs stringForColumn:@"value"];
    switch (eventType) {
        case 3:
        case AMAEventTypeProtobufCrash:
        case AMAEventTypeProtobufANR: {
            NSString *filePath = [value stringByAppendingPathExtension:@"crash"];
            return [[AMAFileEventValue alloc] initWithRelativeFilePath:filePath
                                                        encryptionType:AMAEventEncryptionTypeNoEncryption];
        }

        case AMAEventTypeProfile:
        case AMAEventTypeRevenue:
        case AMAEventTypeProtobufError: {
            NSData *data = [[NSData alloc] initWithBase64EncodedString:value options:0];
            return [[AMABinaryEventValue alloc] initWithData:data gZipped:NO];
        }

        default:
            return [[AMAStringEventValue alloc] initWithValue:value];
    }
}

#pragma mark - Cleanup

- (void)cleanupWithDatabase:(AMAFMDatabase *)db legacyKVKeys:(NSMutableArray *)legacyKVKeys
{
    [db executeUpdate:@"DROP TABLE events"];
    [db executeUpdate:@"DROP TABLE sessions"];
    [self cleanupKVStorageKeys:legacyKVKeys database:db];
}

- (void)cleanupKVStorageKeys:(NSArray *)keys database:(AMAFMDatabase *)db
{
    NSMutableString *placeholders = [NSMutableString stringWithCapacity:keys.count * 2];
    for (NSUInteger idx = 0; idx < keys.count; ++idx) {
        [placeholders appendString:idx == 0 ? @"?" : @",?"];
    }
    NSString *query = [NSString stringWithFormat:@"DELETE FROM kv WHERE k IN (%@)", placeholders];
    [db executeUpdate:query values:keys error:nil];
}

@end
