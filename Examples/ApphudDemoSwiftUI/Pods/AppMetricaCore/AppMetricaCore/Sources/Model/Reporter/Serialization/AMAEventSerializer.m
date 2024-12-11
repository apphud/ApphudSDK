
#import "AMACore.h"
#import "AMAEventSerializer.h"
#import "AMAProtoConversionUtility.h"
#import "AMADatabaseConstants.h"
#import "AMAEvent.h"
#import "AMAStringEventValue.h"
#import "AMABinaryEventValue.h"
#import "AMAFileEventValue.h"
#import "EventData.pb-c.h"
#import "AMAReporterDatabaseEncodersFactory.h"
#import "AMATypeSafeDictionaryHelper.h"
#import "AMAModelSerialization.h"
#import <CoreLocation/CoreLocation.h>
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>
#import "AMAReporterDatabaseEncodersFactory+Migration.h"

@interface AMAEventSerializer ()

@property (nonatomic, assign, readonly) AMAReporterDatabaseEncryptionType encryptionType;
@property (nonatomic, strong, readonly) id<AMADataEncoding> encoder;
@property (nonatomic, assign, readonly) BOOL useMigrationEncoder;

@end

@implementation AMAEventSerializer

- (instancetype)init
{
    AMAReporterDatabaseEncryptionType encryptionType = [AMAReporterDatabaseEncodersFactory eventDataEncryptionType];
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

- (NSDictionary *)dictionaryForEvent:(AMAEvent *)event error:(NSError **)error
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];
    result[kAMACommonTableFieldOID] = event.oid;
    result[kAMAEventTableFieldSessionOID] = event.sessionOid;
    if (event.createdAt) {
        result[kAMAEventTableFieldCreatedAt] = @([event.createdAt timeIntervalSinceReferenceDate]);
    }
    result[kAMAEventTableFieldSequenceNumber] = @(event.sequenceNumber);
    result[kAMACommonTableFieldType] = @(event.type);
    result[kAMACommonTableFieldDataEncryptionType] = @(self.encryptionType);

    NSError *internalError = nil;
    result[kAMACommonTableFieldData] = [self.encoder encodeData:[self dataForEvent:event] error:&internalError];

    if (internalError != nil) {
        AMALogError(@"Failed to serialize event: %@", internalError);
        [AMAErrorUtilities fillError:error withError:internalError];
        result = nil;
    }
    return [result copy];
}

- (NSData *)dataForEvent:(AMAEvent *)event
{
    NSData *__block data = nil;
    [AMAAllocationsTrackerProvider track:^(id<AMAAllocationsTracking> tracker) {
        Ama__EventData eventData = AMA__EVENT_DATA__INIT;
        eventData.payload = [self eventPayloadWithEvent:event tracker:tracker];

        eventData.time_offset = (double)event.timeSinceSession;
        eventData.global_number = (uint32_t)event.globalNumber;
        eventData.number_of_type = (uint32_t)event.numberOfType;
        eventData.source = [AMAProtoConversionUtility eventSourceToServerProto:event.source];
        eventData.has_source = true;
        eventData.attribution_id_changed = event.attributionIDChanged;
        eventData.has_attribution_id_changed = true;
        eventData.has_open_id = true;
        if (event.openID != nil) {
            eventData.open_id = event.openID.unsignedLongValue;
        }
        eventData.has_first_occurrence = [AMAProtoConversionUtility fillBoolValue:&eventData.first_occurrence
                                                                 withOptionalBool:event.firstOccurrence];
        
        eventData.location = [self eventLocationForLocation:event.location tracker:tracker];
        eventData.has_location_enabled = [AMAProtoConversionUtility fillBoolValue:&eventData.location_enabled
                                                                 withOptionalBool:event.locationEnabled];
        
        eventData.has_app_environment = [self fillJSONData:&eventData.app_environment
                                            withDictionary:event.appEnvironment
                                                   tracker:tracker];
        eventData.has_event_environment = [self fillJSONData:&eventData.event_environment
                                              withDictionary:event.eventEnvironment
                                                     tracker:tracker];

        eventData.has_user_profile_id = [AMAProtobufUtilities fillBinaryData:&eventData.user_profile_id
                                                                  withString:event.profileID
                                                                     tracker:tracker];

        eventData.n_extras = [self fillExtras:&eventData.extras
                               withDictionary:event.extras
                                      tracker:tracker];

        size_t dataSize = ama__event_data__get_packed_size(&eventData);
        uint8_t *dataBytes = malloc(dataSize);
        ama__event_data__pack(&eventData, dataBytes);
        data = [NSData dataWithBytesNoCopy:dataBytes length:dataSize];
    }];
    return data;
}

- (Ama__EventData__Payload *)eventPayloadWithEvent:(AMAEvent *)event
                                           tracker:(id<AMAAllocationsTracking>)tracker
{
    Ama__EventData__Payload *payload = [tracker allocateSize:sizeof(Ama__EventData__Payload)];
    ama__event_data__payload__init(payload);
    payload->has_name = [AMAProtobufUtilities fillBinaryData:&payload->name
                                                  withString:event.name
                                                     tracker:tracker];

    NSData *valueData = nil;
    if (event.value == nil) {
        payload->value_type = AMA__EVENT_DATA__PAYLOAD__VALUE_TYPE__EMPTY;
    }
    else if ([event.value isKindOfClass:[AMAStringEventValue class]]) {
        AMAStringEventValue *stringEventValue = (AMAStringEventValue *)event.value;
        valueData = [stringEventValue.value dataUsingEncoding:NSUTF8StringEncoding];
        payload->value_type = AMA__EVENT_DATA__PAYLOAD__VALUE_TYPE__STRING;
    }
    else if ([event.value isKindOfClass:[AMABinaryEventValue class]]) {
        AMABinaryEventValue *binaryEventValue = (AMABinaryEventValue *)event.value;
        valueData = binaryEventValue.data;
        payload->value_type = AMA__EVENT_DATA__PAYLOAD__VALUE_TYPE__BINARY;
    }
    else if ([event.value isKindOfClass:[AMAFileEventValue class]]) {
        AMAFileEventValue *fileEventValue = (AMAFileEventValue *)event.value;
        valueData = [fileEventValue.relativeFilePath dataUsingEncoding:NSUTF8StringEncoding];
        payload->value_type = AMA__EVENT_DATA__PAYLOAD__VALUE_TYPE__FILE;
    }
    else {
        AMALogAssert(@"Unknown event value type");
        payload->value_type = AMA__EVENT_DATA__PAYLOAD__VALUE_TYPE__EMPTY;
    }

    payload->has_value_data = [AMAProtobufUtilities fillBinaryData:&payload->value_data
                                                          withData:valueData
                                                           tracker:tracker];
    if (event.value != nil) {
        payload->encryption_type = [self encryptionTypeForType:event.value.encryptionType];
    }
    payload->bytes_truncated = (uint32_t)event.bytesTruncated;
    return payload;
}

- (Ama__EventData__Payload__EncryptionType)encryptionTypeForType:(AMAEventEncryptionType)type
{
    switch (type) {
        case AMAEventEncryptionTypeNoEncryption:
            return AMA__EVENT_DATA__PAYLOAD__ENCRYPTION_TYPE__NONE;
        case AMAEventEncryptionTypeAESv1:
            return AMA__EVENT_DATA__PAYLOAD__ENCRYPTION_TYPE__AES;
        case AMAEventEncryptionTypeGZip:
            return AMA__EVENT_DATA__PAYLOAD__ENCRYPTION_TYPE__GZIP;
        default:
            return AMA__EVENT_DATA__PAYLOAD__ENCRYPTION_TYPE__NONE;
    }
}

- (Ama__EventData__Location *)eventLocationForLocation:(CLLocation *)location
                                               tracker:(id<AMAAllocationsTracking>)tracker
{
    if (location == nil) {
        return NULL;
    }

    Ama__EventData__Location *locationData = [tracker allocateSize:sizeof(Ama__EventData__Location)];
    ama__event_data__location__init(locationData);
    locationData->latitude = (double)location.coordinate.latitude;
    locationData->longitude = (double)location.coordinate.longitude;
    locationData->altitude = (double)location.altitude;

    locationData->has_timestamp = location.timestamp != nil;
    if (locationData->has_timestamp) {
        locationData->timestamp = (double)[location.timestamp timeIntervalSinceReferenceDate];
    }

#if TARGET_OS_TV
    locationData->speed = -1.0;
    locationData->direction = -1.0;
#else
    locationData->speed = (double)location.speed;
    locationData->direction = (double)location.course;
#endif
    locationData->horizontal_accuracy = (double)location.horizontalAccuracy;
    locationData->vertical_accuracy = (double)location.verticalAccuracy;
    return locationData;
}

- (BOOL)fillJSONData:(ProtobufCBinaryData *)binaryData
      withDictionary:(NSDictionary *)dictionary
             tracker:(id<AMAAllocationsTracking>)tracker
{
    if (dictionary.count == 0) {
        return NO;
    }

    NSError *error = nil;
    NSString *jsonString = [AMAJSONSerialization stringWithJSONObject:dictionary error:&error];
    if (jsonString == nil) {
        AMALogError(@"Failed to serialize dictionary to JSON: %@", error);
        return NO;
    }

    return [AMAProtobufUtilities fillBinaryData:binaryData
                                     withString:jsonString
                                        tracker:tracker];
}

- (size_t)fillExtras:(Ama__EventData__ExtraEntry ***)extras
      withDictionary:(NSDictionary<NSString *, NSData *> *)dictionary
             tracker:(id <AMAAllocationsTracking>)tracker
{
    if (dictionary.count == 0) {
        *extras = NULL;
        return 0;
    }

    Ama__EventData__ExtraEntry **extrasArray = [tracker allocateSize:sizeof(Ama__EventData__ExtraEntry *)];
    size_t i = 0;

    for (NSString *key in dictionary.keyEnumerator) {
        Ama__EventData__ExtraEntry *extra = [tracker allocateSize:sizeof(Ama__EventData__ExtraEntry)];
        ama__event_data__extra_entry__init(extra);

        [AMAProtobufUtilities fillBinaryData:&extra->key
                                  withString:key
                                     tracker:tracker];

        [AMAProtobufUtilities fillBinaryData:&extra->value
                                    withData:dictionary[key]
                                     tracker:tracker];

        extrasArray[i] = extra;
        i++;
    }

    *extras = extrasArray;

    return dictionary.count;
}

#pragma mark - Deserialization -

- (AMAEvent *)eventForDictionary:(NSDictionary *)dictionary error:(NSError **)error
{
    AMA_GUARD_ENSURE_TYPE_OR_RETURN(NSNumber,  oid,                    dictionary[kAMACommonTableFieldOID]);
    AMA_GUARD_ENSURE_TYPE_OR_RETURN(NSNumber,  sessionOid,             dictionary[kAMAEventTableFieldSessionOID]);
    AMA_GUARD_ENSURE_TYPE_OR_RETURN(NSNumber,  createdAtNumber,        dictionary[kAMAEventTableFieldCreatedAt]);
    AMA_GUARD_ENSURE_TYPE_OR_RETURN(NSNumber,  sequenceNumber,         dictionary[kAMAEventTableFieldSequenceNumber]);
    AMA_GUARD_ENSURE_TYPE_OR_RETURN(NSNumber,  type,                   dictionary[kAMACommonTableFieldType]);
    AMA_GUARD_ENSURE_TYPE_OR_RETURN(NSNumber,  encryptionTypeNumber,   dictionary[kAMACommonTableFieldDataEncryptionType]);
    AMA_GUARD_ENSURE_TYPE_OR_RETURN(NSData,    encodedData,            dictionary[kAMACommonTableFieldData]);

    AMAEvent *event = nil;
    @try {
        event = [self eventForOid:oid
                       sessionOid:sessionOid
                  createdAtNumber:createdAtNumber
                   sequenceNumber:sequenceNumber
                             type:type
             encryptionTypeNumber:encryptionTypeNumber
                      encodedData:encodedData
                            error:error];
    }
    @catch (NSException *exception) {
        [AMAErrorUtilities fillError:error
              withInternalErrorName:[NSString stringWithFormat:@"Exception: %@", exception]];
    }
    return event;
}

- (AMAEvent *)eventForOid:(NSNumber *)oid
               sessionOid:(NSNumber *)sessionOid
          createdAtNumber:(NSNumber *)createdAtNumber
           sequenceNumber:(NSNumber *)sequenceNumber
                     type:(NSNumber *)type
     encryptionTypeNumber:(NSNumber *)encryptionTypeNumber
              encodedData:(NSData *)encodedData
                    error:(NSError **)error
{
    AMAEvent *event = [[AMAEvent alloc] init];
    event.oid = oid;
    event.sessionOid = sessionOid;
    if (createdAtNumber != nil) {
        event.createdAt = [NSDate dateWithTimeIntervalSinceReferenceDate:[createdAtNumber doubleValue]];
    }
    event.sequenceNumber = [sequenceNumber unsignedIntegerValue];
    event.type = [type unsignedIntegerValue];

    AMAReporterDatabaseEncryptionType encryptionType =
        (AMAReporterDatabaseEncryptionType)[encryptionTypeNumber unsignedIntegerValue];
    id<AMADataEncoding> encoder = self.encoder;
    if (encryptionType != self.encryptionType) {
        encoder = [self encoderForEncryptionType:encryptionType];
    }

    NSError *internalError = nil;
    NSData *data = [encoder decodeData:encodedData error:&internalError];
    if (internalError == nil) {
        [self fillEvent:event withData:data error:&internalError];
    }

    if (internalError != nil) {
        AMALogError(@"Failed to deserialize event: %@", internalError);
        [AMAErrorUtilities fillError:error withError:internalError];
        event = nil;
    }
    return event;
}

- (BOOL)fillEvent:(AMAEvent *)event withData:(NSData *)data error:(NSError **)error
{
    if (data.length == 0) {
        [AMAErrorUtilities fillError:error withInternalErrorName:@"Data is empty"];
        return NO;
    }

    NS_VALID_UNTIL_END_OF_SCOPE AMAProtobufAllocator *allocator = [[AMAProtobufAllocator alloc] init];
    Ama__EventData *eventData = ama__event_data__unpack(allocator.protobufCAllocator, data.length, data.bytes);
    if (eventData == NULL) {
        [AMAErrorUtilities fillError:error withInternalErrorName:@"Data is not a valid protobuf"];
        return NO;
    }

    [self fillEvent:event withPayload:eventData->payload];

    event.timeSinceSession = (NSTimeInterval)eventData->time_offset;
    event.globalNumber = (NSUInteger)eventData->global_number;
    event.numberOfType = (NSUInteger)eventData->number_of_type;
    event.source = [AMAProtoConversionUtility eventSourceToModel:eventData->source];
    event.attributionIDChanged = (BOOL)eventData->attribution_id_changed;
    event.firstOccurrence = [AMAProtoConversionUtility optionalBoolForBoolValue:eventData->first_occurrence
                                                                       hasValue:eventData->has_first_occurrence];
    
    event.location = [self locationForLocationData:eventData->location];
    event.locationEnabled = [AMAProtoConversionUtility optionalBoolForBoolValue:eventData->location_enabled
                                                                       hasValue:eventData->has_location_enabled];
    
    event.appEnvironment = [self dictionaryForJSONData:&eventData->app_environment
                                                   has:eventData->has_app_environment];
    event.eventEnvironment = [self dictionaryForJSONData:&eventData->event_environment
                                                     has:eventData->has_event_environment];
    
    if (eventData->has_user_profile_id) {
        event.profileID = [AMAProtobufUtilities stringForBinaryData:&eventData->user_profile_id];
    }
    event.openID = @(eventData->open_id);

    event.extras = [self extrasDictionaryForProtobuf:eventData->extras count:eventData->n_extras];

    return YES;
}

- (void)fillEvent:(AMAEvent *)event withPayload:(Ama__EventData__Payload *)payload
{
    if (payload->has_name) {
        event.name = [AMAProtobufUtilities stringForBinaryData:&payload->name];
    }
    event.value = [self eventValueForPayload:payload];
    event.bytesTruncated = (NSUInteger)payload->bytes_truncated;
}

- (id<AMAEventValueProtocol>)eventValueForPayload:(Ama__EventData__Payload *)payload
{
    NSData *valueData = [AMAProtobufUtilities dataForBinaryData:&payload->value_data
                                                            has:payload->has_value_data];
    switch (payload->value_type) {
        case AMA__EVENT_DATA__PAYLOAD__VALUE_TYPE__EMPTY:
        default:
            return nil;

        case AMA__EVENT_DATA__PAYLOAD__VALUE_TYPE__STRING: {
            NSString *stringValue = [[NSString alloc] initWithData:valueData encoding:NSUTF8StringEncoding];
            return [[AMAStringEventValue alloc] initWithValue:stringValue];
        }

        case AMA__EVENT_DATA__PAYLOAD__VALUE_TYPE__BINARY: {
            AMAEventEncryptionType encryptionType = [self eventEncryptionTypeForType:payload->encryption_type];
            BOOL gZipped = encryptionType == AMAEventEncryptionTypeGZip;
            return [[AMABinaryEventValue alloc] initWithData:valueData gZipped:gZipped];
        }

        case AMA__EVENT_DATA__PAYLOAD__VALUE_TYPE__FILE: {
            NSString *filePath = [[NSString alloc] initWithData:valueData encoding:NSUTF8StringEncoding];
            AMAEventEncryptionType encryptionType = [self eventEncryptionTypeForType:payload->encryption_type];
            return [[AMAFileEventValue alloc] initWithRelativeFilePath:filePath
                                                        encryptionType:encryptionType];
        }
    }
}

- (CLLocation *)locationForLocationData:(Ama__EventData__Location *)locationData
{
    if (locationData == NULL) {
        return nil;
    }
    if (locationData->has_timestamp == false) {
        AMALogAssert(@"No location timestamp for non-null location. Location is dropped.");
        return nil;
    }

    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(locationData->latitude, locationData->longitude);
    NSDate *timestamp = [NSDate dateWithTimeIntervalSinceReferenceDate:(NSTimeInterval)locationData->timestamp];
#if TARGET_OS_TV
    return [[CLLocation alloc] initWithCoordinate:coordinate
                                         altitude:locationData->altitude
                               horizontalAccuracy:locationData->horizontal_accuracy
                                 verticalAccuracy:locationData->vertical_accuracy
                                        timestamp:timestamp];
#else
    return [[CLLocation alloc] initWithCoordinate:coordinate
                                         altitude:locationData->altitude
                               horizontalAccuracy:locationData->horizontal_accuracy
                                 verticalAccuracy:locationData->vertical_accuracy
                                           course:locationData->direction
                                            speed:locationData->speed
                                        timestamp:timestamp];
#endif
}

- (AMAEventEncryptionType)eventEncryptionTypeForType:(Ama__EventData__Payload__EncryptionType)type
{
    switch (type) {
        case AMA__EVENT_DATA__PAYLOAD__ENCRYPTION_TYPE__NONE:
        default:
            return AMAEventEncryptionTypeNoEncryption;
        case AMA__EVENT_DATA__PAYLOAD__ENCRYPTION_TYPE__AES:
            return AMAEventEncryptionTypeAESv1;
        case AMA__EVENT_DATA__PAYLOAD__ENCRYPTION_TYPE__GZIP:
            return AMAEventEncryptionTypeGZip;
    }
}

- (NSDictionary *)dictionaryForJSONData:(ProtobufCBinaryData *)data
                                    has:(protobuf_c_boolean)hasValue
{
    NSDictionary *result = nil;
    NSString *jsonString = [AMAProtobufUtilities stringForBinaryData:data has:hasValue];
    if (jsonString != nil) {
        NSError *error = nil;
        result = [AMAJSONSerialization dictionaryWithJSONString:jsonString error:&error];
        if (error != nil) {
            AMALogError(@"Failed to serialize dictionary to JSON: %@", error);
        }
    }
    return result;
}

- (NSDictionary<NSString *, NSData *> *)extrasDictionaryForProtobuf:(Ama__EventData__ExtraEntry**)extras count:(size_t)count {
    if (count == 0) {
        return nil;
    }

    NSMutableDictionary<NSString *, NSData *> *result = [NSMutableDictionary dictionary];

    for (size_t i = 0; i < count; i++) {
        Ama__EventData__ExtraEntry *extra = extras[i];
        NSString *key = [AMAProtobufUtilities stringForBinaryData:&extra->key];
        NSData *value = [AMAProtobufUtilities dataForBinaryData:&extra->value];

        result[key] = value;
    }

    return result;
}

#pragma mark - Migration -

- (instancetype)migrationInit
{
    AMAReporterDatabaseEncryptionType encryptionType = [AMAReporterDatabaseEncodersFactory eventDataEncryptionType];
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
