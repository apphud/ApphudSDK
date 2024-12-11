
#import "AMACore.h"
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMASessionSerializer.h"
#import "AMADatabaseConstants.h"
#import "AMASession.h"
#import "AMADate.h"
#import "SessionData.pb-c.h"
#import "AMAReporterDatabaseEncodersFactory.h"
#import "AMATypeSafeDictionaryHelper.h"
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>
#import "AMAReporterDatabaseEncodersFactory+Migration.h"

@interface AMASessionSerializer ()

@property (nonatomic, assign, readonly) AMAReporterDatabaseEncryptionType encryptionType;
@property (nonatomic, strong, readonly) id<AMADataEncoding> encoder;
@property (nonatomic, assign, readonly) BOOL useMigrationEncoder;

@end

@implementation AMASessionSerializer

- (instancetype)init
{
    AMAReporterDatabaseEncryptionType encryptionType = [AMAReporterDatabaseEncodersFactory sessionDataEncryptionType];
    return [self initWithEncryptionType:encryptionType
                                encoder:[AMAReporterDatabaseEncodersFactory encoderForEncryptionType:encryptionType]
                    useMigrationEncoder:NO];
}

- (instancetype)initWithEncryptionType:(AMAReporterDatabaseEncryptionType)encryptionType
                               encoder:(id<AMADataEncoding>)encoder
                   useMigrationEncoder:(BOOL)useMigrationEncoder
{
    self = [super init];
    if (self != nil) {
        _encryptionType = encryptionType;
        _encoder = encoder;
        _useMigrationEncoder = useMigrationEncoder;
    }
    return self;
}

#pragma mark - Serialization -

- (NSDictionary *)dictionaryForSession:(AMASession *)session error:(NSError **)error
{
    NSMutableDictionary *dictionary = [NSMutableDictionary dictionary];
    dictionary[kAMACommonTableFieldOID] = session.oid;
    dictionary[kAMASessionTableFieldStartTime] = [self numberForDate:session.startDate.deviceDate];
    dictionary[kAMACommonTableFieldType] = @(session.type);
    dictionary[kAMASessionTableFieldFinished] = @(session.finished);
    dictionary[kAMASessionTableFieldLastEventTime] = [self numberForDate:session.lastEventTime];
    dictionary[kAMASessionTableFieldPauseTime] = [self numberForDate:session.pauseTime];
    dictionary[kAMASessionTableFieldEventSeq] = @(session.eventSeq);
    dictionary[kAMACommonTableFieldDataEncryptionType] = @(self.encryptionType);

    NSError *internalError = nil;
    dictionary[kAMACommonTableFieldData] = [self commonDataForSession:session error:&internalError];

    if (internalError != nil) {
        AMALogError(@"Failed to serialize session: %@", internalError);
        dictionary = nil;
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return [dictionary copy];
}

- (NSData *)commonDataForSession:(AMASession *)session error:(NSError **)error
{
    return [self.encoder encodeData:[self dataForSession:session] error:error];
}

- (NSNumber *)numberForDate:(NSDate *)date
{
    if (date == nil) {
        return nil;
    }
    return @(date.timeIntervalSinceReferenceDate);
}

- (NSData *)dataForSession:(AMASession *)session
{
    NSData *__block data = nil;
    [AMAAllocationsTrackerProvider track:^(id<AMAAllocationsTracking> tracker) {
        Ama__SessionData sessionData = AMA__SESSION_DATA__INIT;

        sessionData.session_id = (int64_t)[session.sessionID longLongValue];
        sessionData.has_attribution_id = [AMAProtobufUtilities fillBinaryData:&sessionData.attribution_id
                                                                   withString:session.attributionID
                                                                      tracker:tracker];

        sessionData.has_server_time_offset = session.startDate.serverTimeOffset != nil;
        if (sessionData.has_server_time_offset) {
            sessionData.server_time_offset = (int32_t)[session.startDate.serverTimeOffset integerValue];
        }

        sessionData.app_state = [self appStateForState:session.appState tracker:tracker];

        size_t dataSize = ama__session_data__get_packed_size(&sessionData);
        uint8_t *bytes = malloc(dataSize);
        ama__session_data__pack(&sessionData, bytes);
        data = [NSData dataWithBytesNoCopy:bytes length:dataSize];
    }];
    return data;
}

- (Ama__SessionData__AppState *)appStateForState:(AMAApplicationState *)appState
                                         tracker:(id<AMAAllocationsTracking>)tracker
{
    Ama__SessionData__AppState *appStateData = [tracker allocateSize:sizeof(Ama__SessionData__AppState)];
    ama__session_data__app_state__init(appStateData);

    appStateData->has_locale = [AMAProtobufUtilities fillBinaryData:&appStateData->locale
                                                         withString:appState.locale
                                                            tracker:tracker];
    appStateData->has_app_version_name = [AMAProtobufUtilities fillBinaryData:&appStateData->app_version_name
                                                                   withString:appState.appVersionName
                                                                      tracker:tracker];
    appStateData->has_kit_version = [AMAProtobufUtilities fillBinaryData:&appStateData->kit_version
                                                              withString:appState.kitVersion
                                                                 tracker:tracker];
    appStateData->has_kit_version_name = [AMAProtobufUtilities fillBinaryData:&appStateData->kit_version_name
                                                                   withString:appState.kitVersionName
                                                                      tracker:tracker];
    appStateData->has_kit_build_type = [AMAProtobufUtilities fillBinaryData:&appStateData->kit_build_type
                                                                 withString:appState.kitBuildType
                                                                    tracker:tracker];
    appStateData->has_os_version = [AMAProtobufUtilities fillBinaryData:&appStateData->os_version
                                                             withString:appState.OSVersion
                                                                tracker:tracker];
    appStateData->has_uuid = [AMAProtobufUtilities fillBinaryData:&appStateData->uuid
                                                       withString:appState.UUID
                                                          tracker:tracker];
    appStateData->has_device_id = [AMAProtobufUtilities fillBinaryData:&appStateData->device_id
                                                            withString:appState.deviceID
                                                               tracker:tracker];
    appStateData->has_ifv = [AMAProtobufUtilities fillBinaryData:&appStateData->ifv
                                                      withString:appState.IFV
                                                         tracker:tracker];
    appStateData->has_ifa = [AMAProtobufUtilities fillBinaryData:&appStateData->ifa
                                                      withString:appState.IFA
                                                         tracker:tracker];
    appStateData->has_app_build_number = [AMAProtobufUtilities fillBinaryData:&appStateData->app_build_number
                                                                   withString:appState.appBuildNumber
                                                                      tracker:tracker];

    appStateData->app_debuggable = appState.appDebuggable;
    appStateData->os_api_level = (int32_t)appState.OSAPILevel;
    appStateData->kit_build_number = (uint32_t)appState.kitBuildNumber;
    appStateData->is_rooted = appState.isRooted;
    appStateData->lat = appState.LAT;
    return appStateData;
}

#pragma mark - Deserialization

- (AMASession *)sessionForDictionary:(NSDictionary *)dictionary error:(NSError **)error
{
    AMA_GUARD_ENSURE_TYPE_OR_RETURN(NSNumber,  oid,                    dictionary[kAMACommonTableFieldOID]);
    AMA_GUARD_ENSURE_TYPE_OR_RETURN(NSNumber,  startTime,              dictionary[kAMASessionTableFieldStartTime]);
    AMA_GUARD_ENSURE_TYPE_OR_RETURN(NSNumber,  type,                   dictionary[kAMACommonTableFieldType]);
    AMA_GUARD_ENSURE_TYPE_OR_RETURN(NSNumber,  finished,               dictionary[kAMASessionTableFieldFinished]);
    AMA_GUARD_ENSURE_TYPE_OR_RETURN(NSNumber,  lastEventTime,          dictionary[kAMASessionTableFieldLastEventTime]);
    AMA_GUARD_ENSURE_TYPE_OR_RETURN(NSNumber,  pauseTime,              dictionary[kAMASessionTableFieldPauseTime]);
    AMA_GUARD_ENSURE_TYPE_OR_RETURN(NSNumber,  eventSeq,               dictionary[kAMASessionTableFieldEventSeq]);
    AMA_GUARD_ENSURE_TYPE_OR_RETURN(NSNumber,  encryptionTypeNumber,   dictionary[kAMACommonTableFieldDataEncryptionType]);
    AMA_GUARD_ENSURE_TYPE_OR_RETURN(NSData,    encodedData,            dictionary[kAMACommonTableFieldData]);

    AMASession *session = nil;
    @try {
        session = [self sessionForOid:oid
                            startTime:startTime
                                 type:type
                             finished:finished
                        lastEventTime:lastEventTime
                            pauseTime:pauseTime
                             eventSeq:eventSeq
                 encryptionTypeNumber:encryptionTypeNumber
                          encodedData:encodedData
                                error:error];
    }
    @catch (NSException *exception) {
        [AMAErrorUtilities fillError:error
              withInternalErrorName:[NSString stringWithFormat:@"Exception: %@", exception]];
    }
    return session;
}

- (AMASession *)sessionForOid:(NSNumber *)oid
                    startTime:(NSNumber *)startTime
                         type:(NSNumber *)type
                     finished:(NSNumber *)finished
                lastEventTime:(NSNumber *)lastEventTime
                    pauseTime:(NSNumber *)pauseTime
                     eventSeq:(NSNumber *)eventSeq
         encryptionTypeNumber:(NSNumber *)encryptionTypeNumber
                  encodedData:(NSData *)encodedData
                        error:(NSError **)error
{
    AMASession *session = [[AMASession alloc] init];
    session.oid = oid;
    session.startDate = [[AMADate alloc] init];
    session.startDate.deviceDate = [self dateForNumber:startTime];
    session.type = (AMASessionType)[type unsignedIntegerValue];
    session.finished = [finished boolValue];
    session.lastEventTime = [self dateForNumber:lastEventTime];
    session.pauseTime = [self dateForNumber:pauseTime];
    session.eventSeq = [eventSeq unsignedIntegerValue];

    AMAReporterDatabaseEncryptionType encryptionType =
        (AMAReporterDatabaseEncryptionType)[encryptionTypeNumber unsignedIntegerValue];
    id<AMADataEncoding> encoder = self.encoder;
    if (encryptionType != self.encryptionType) {
        encoder = [self encoderForEncryptionType:encryptionType];
    }

    NSError *internalError = nil;
    NSData *data = [encoder decodeData:encodedData error:&internalError];
    if (internalError == nil) {
        [self fillSession:session withData:data error:&internalError];
    }

    if (internalError != nil) {
        AMALogError(@"Failed to deserialize session: %@", internalError);
        [AMAErrorUtilities fillError:error withError:internalError];
        session = nil;
    }
    return session;
}

- (NSDate *)dateForNumber:(NSNumber *)number
{
    if (number == nil || (id)number == [NSNull null]) {
        return nil;
    }
    return [NSDate dateWithTimeIntervalSinceReferenceDate:number.doubleValue];
}

- (BOOL)fillSession:(AMASession *)session withData:(NSData *)data error:(NSError **)error
{
    if (data.length == 0) {
        [AMAErrorUtilities fillError:error withInternalErrorName:@"Data is empty"];
        return NO;
    }

    NS_VALID_UNTIL_END_OF_SCOPE AMAProtobufAllocator *allocator = [[AMAProtobufAllocator alloc] init];
    Ama__SessionData *sessionData = ama__session_data__unpack(allocator.protobufCAllocator, data.length, data.bytes);
    if (sessionData == NULL) {
        [AMAErrorUtilities fillError:error withInternalErrorName:@"Data is not a valid protobuf"];
        return NO;
    }

    session.sessionID = [NSNumber numberWithLongLong:sessionData->session_id];
    session.attributionID = [AMAProtobufUtilities stringForBinaryData:&sessionData->attribution_id
                                                                  has:sessionData->has_attribution_id];
    if (sessionData->has_server_time_offset) {
        session.startDate.serverTimeOffset = [NSNumber numberWithInteger:(NSInteger)sessionData->server_time_offset];
    }
    session.appState = [self appStateForAppStateData:sessionData->app_state];

    return YES;
}

- (AMAApplicationState *)appStateForAppStateData:(Ama__SessionData__AppState *)appStateData
{
    AMAMutableApplicationState *appState = [[AMAMutableApplicationState alloc] init];
    appState.locale = [AMAProtobufUtilities stringForBinaryData:&appStateData->locale
                                                            has:appStateData->has_locale];
    appState.appVersionName = [AMAProtobufUtilities stringForBinaryData:&appStateData->app_version_name
                                                                    has:appStateData->has_app_version_name];
    appState.appDebuggable = (BOOL)appStateData->app_debuggable;
    appState.kitVersion = [AMAProtobufUtilities stringForBinaryData:&appStateData->kit_version
                                                                has:appStateData->has_kit_version];
    appState.kitVersionName = [AMAProtobufUtilities stringForBinaryData:&appStateData->kit_version_name
                                                                    has:appStateData->has_kit_version_name];
    appState.kitBuildType = [AMAProtobufUtilities stringForBinaryData:&appStateData->kit_build_type
                                                                  has:appStateData->has_kit_build_type];
    appState.kitBuildNumber = (NSUInteger)appStateData->kit_build_number;
    appState.OSVersion = [AMAProtobufUtilities stringForBinaryData:&appStateData->os_version
                                                               has:appStateData->has_os_version];
    appState.OSAPILevel = (NSInteger)appStateData->os_api_level;
    appState.isRooted = (BOOL)appStateData->is_rooted;
    appState.UUID = [AMAProtobufUtilities stringForBinaryData:&appStateData->uuid
                                                            has:appStateData->has_uuid];
    appState.deviceID = [AMAProtobufUtilities stringForBinaryData:&appStateData->device_id
                                                              has:appStateData->has_device_id];
    appState.IFV = [AMAProtobufUtilities stringForBinaryData:&appStateData->ifv
                                                         has:appStateData->has_ifv];
    appState.IFA = [AMAProtobufUtilities stringForBinaryData:&appStateData->ifa
                                                         has:appStateData->has_ifa];
    appState.LAT = (BOOL)appStateData->lat;
    appState.appBuildNumber = [AMAProtobufUtilities stringForBinaryData:&appStateData->app_build_number
                                                                    has:appStateData->has_app_build_number];
    return [appState copy];
}

#pragma mark - Migration -

- (instancetype)migrationInit
{
    AMAReporterDatabaseEncryptionType encryptionType = [AMAReporterDatabaseEncodersFactory sessionDataEncryptionType];
    return [self initWithEncryptionType:encryptionType
                                encoder:[AMAReporterDatabaseEncodersFactory migrationEncoderForEncryptionType:encryptionType]
                    useMigrationEncoder:YES];
}

- (id<AMADataEncoding>)encoderForEncryptionType:(AMAReporterDatabaseEncryptionType)encryptionType
{
    if (self.useMigrationEncoder) {
        return [AMAReporterDatabaseEncodersFactory migrationEncoderForEncryptionType:encryptionType];
    }
    else {
        return [AMAReporterDatabaseEncodersFactory encoderForEncryptionType:encryptionType];
    }
}

@end
