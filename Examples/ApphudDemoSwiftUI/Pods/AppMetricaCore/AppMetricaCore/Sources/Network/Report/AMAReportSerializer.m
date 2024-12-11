
#import <CoreLocation/CoreLocation.h>
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>
#import "AMACore.h"
#import "AMAReportSerializer.h"
#import "AMAProtoConversionUtility.h"
#import "AppMetrica.pb-c.h"
#import "AMAReportRequestModel.h"
#import "AMAReportEventsBatch.h"
#import "AMAEvent.h"
#import "AMAStringEventValue.h"
#import "AMABinaryEventValue.h"
#import "AMAFileEventValue.h"
#import "AMASession.h"
#import "AMADate.h"

NSString *const kAMAReportSerializerErrorDomain = @"kAMAReportSerializerErrorDomain";
NSString *const kAMAReportSerializerErrorKeyActualSize = @"kAMAReportSerializerErrorKeyActualSize";

@implementation AMAReportSerializer

#define AMA_ENSURE_MEMORY_ALLOCATED(var) \
    if ((var) == NULL) { \
        [self fillAllocationError:error]; \
        return NO; \
    }

#pragma mark - General

- (NSData *)dataForRequestModel:(AMAReportRequestModel *)requestModel
                      sizeLimit:(NSUInteger)sizeLimit
                          error:(NSError **)error
{
    NSData *__block resultData = nil;
    NSError *__block internalError = nil;
    [AMAAllocationsTrackerProvider track:^(id<AMAAllocationsTracking> tracker) {
        Ama__ReportMessage reportMessage = AMA__REPORT_MESSAGE__INIT;
        BOOL result = YES;
        result = result && [self fillReportMessage:&reportMessage
                                  withEventBatches:requestModel.eventsBatches
                                           tracker:tracker
                                             error:&internalError];
        result = result && [self fillReportMessage:&reportMessage
                                withAppEnvironment:requestModel.appEnvironment
                                           tracker:tracker
                                             error:&internalError];
        result = result && [self fillReportMessage:&reportMessage
                                      withAppState:requestModel.appState
                                           tracker:tracker
                                             error:&internalError];

        if (result) {
            resultData = [self dataForReportMessage:&reportMessage sizeLimit:sizeLimit error:&internalError];
        }
    }];

    if (internalError != nil) {
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return resultData;
}

- (NSData *)dataForReportMessage:(Ama__ReportMessage *)reportMessage
                       sizeLimit:(NSUInteger)sizeLimit
                           error:(NSError **)error
{
    NSData *result = nil;
    size_t dataSize = ama__report_message__get_packed_size(reportMessage);
    if (dataSize > sizeLimit) {
        NSDictionary *userInfo = @{ kAMAReportSerializerErrorKeyActualSize: @(dataSize) };
        [self fillError:error withCode:AMAReportSerializerErrorTooLarge userInfo:userInfo];
        return nil;
    }

    uint8_t *dataBytes = malloc(dataSize);
    if (dataBytes == NULL) {
        [self fillAllocationError:error];
        return nil;
    }

    ama__report_message__pack(reportMessage, dataBytes);
    result = [NSData dataWithBytesNoCopy:dataBytes length:dataSize];
    return result;
}

#pragma mark - Sessions

- (BOOL)fillReportMessage:(Ama__ReportMessage *)reportMessage
         withEventBatches:(NSArray<AMAReportEventsBatch *> *)eventBatches
                  tracker:(id<AMAAllocationsTracking>)tracker
                    error:(NSError **)error
{
    NSUInteger count = eventBatches.count;
    if (count == 0) {
        [self fillError:error withCode:AMAReportSerializerErrorEmpty userInfo:nil];
        return NO;
    }
    reportMessage->sessions = [tracker allocateSize:sizeof(Ama__ReportMessage__Session *) * count];
    AMA_ENSURE_MEMORY_ALLOCATED(reportMessage->sessions);

    NSUInteger index = 0;
    NSError *internalError = nil;
    for (AMAReportEventsBatch *batch in eventBatches) {
        Ama__ReportMessage__Session *session = [tracker allocateSize:sizeof(Ama__ReportMessage__Session)];
        AMA_ENSURE_MEMORY_ALLOCATED(session);
        ama__report_message__session__init(session);
        BOOL result = [self fillSession:session withEventsBatch:batch tracker:tracker error:&internalError];
        if (result == NO) {
            if (internalError.code == AMAReportSerializerErrorEmpty) {
                continue;
            }
            else {
                [AMAErrorUtilities fillError:error withError:internalError];
                return NO;
            }
        }
        reportMessage->sessions[index++] = session;
    }
    if (index == 0) {
        [self fillError:error withCode:AMAReportSerializerErrorEmpty userInfo:nil];
        return NO;
    }
    reportMessage->n_sessions = index;
    return YES;
}

- (BOOL)fillSession:(Ama__ReportMessage__Session *)sessionData
    withEventsBatch:(AMAReportEventsBatch *)batch
            tracker:(id<AMAAllocationsTracking>)tracker
              error:(NSError **)error
{
    sessionData->session_desc = [tracker allocateSize:sizeof(Ama__ReportMessage__Session__SessionDesc)];
    AMA_ENSURE_MEMORY_ALLOCATED(sessionData->session_desc);
    ama__report_message__session__session_desc__init(sessionData->session_desc);

    sessionData->id = (uint64_t)batch.session.sessionID.unsignedLongLongValue;

    BOOL result = YES;
    result = result && [self fillSessionDescription:sessionData->session_desc
                                        withSession:batch.session
                                            tracker:tracker
                                              error:error];
    result = result && [self fillSession:sessionData withEvents:batch.events tracker:tracker error:error];
    return result;
}

- (BOOL)fillSessionDescription:(Ama__ReportMessage__Session__SessionDesc *)descriptionData
                   withSession:(AMASession *)session
                       tracker:(id<AMAAllocationsTracking>)tracker
                         error:(NSError **)error
{
    descriptionData->start_time = [tracker allocateSize:sizeof(Ama__Time)];
    AMA_ENSURE_MEMORY_ALLOCATED(descriptionData->start_time);
    ama__time__init(descriptionData->start_time);
    descriptionData->start_time->timestamp = (uint64_t)[session.startDate.deviceDate timeIntervalSince1970];
    NSTimeZone *zone = [NSTimeZone systemTimeZone];
    descriptionData->start_time->time_zone = (int32_t)[zone secondsFromGMT];

    descriptionData->locale = [AMAProtobufUtilities addNSString:session.appState.locale toTracker:tracker];
    AMA_ENSURE_MEMORY_ALLOCATED(descriptionData->locale);

    descriptionData->has_session_type = 1;
    descriptionData->session_type = [self sessionTypeForType:session.type];

    return YES;
}

#pragma mark - Events

- (BOOL)fillSession:(Ama__ReportMessage__Session *)sessionData
         withEvents:(NSArray<AMAEvent *> *)events
            tracker:(id<AMAAllocationsTracking>)tracker
              error:(NSError **)error
{
    NSUInteger count = events.count;
    sessionData->events = [tracker allocateSize:sizeof(Ama__ReportMessage__Session__Event *) * count];
    AMA_ENSURE_MEMORY_ALLOCATED(sessionData->events);

    NSUInteger index = 0;
    NSError *internalError = nil;
    for (AMAEvent *event in events) {
        Ama__ReportMessage__Session__Event *eventData =
            [tracker allocateSize:sizeof(Ama__ReportMessage__Session__Event)];
        AMA_ENSURE_MEMORY_ALLOCATED(eventData);
        ama__report_message__session__event__init(eventData);
        BOOL result = [self fillEvent:eventData withEvent:event tracker:tracker error:&internalError];
        if (result == NO) {
            if (internalError.code == AMAReportSerializerErrorEmpty) {
                continue;
            }
            else {
                [AMAErrorUtilities fillError:error withError:internalError];
                return NO;
            }
        }
        sessionData->events[index++] = eventData;
    }
    if (index == 0) {
        [self fillError:error withCode:AMAReportSerializerErrorEmpty userInfo:nil];
        return NO;
    }
    sessionData->n_events = index;
    return YES;
}

- (BOOL)fillEvent:(Ama__ReportMessage__Session__Event *)eventData
        withEvent:(AMAEvent *)event
          tracker:(id<AMAAllocationsTracking>)tracker
            error:(NSError **)error
{
    if (event.name != nil) {
        eventData->name = [AMAProtobufUtilities addNSString:event.name toTracker:tracker];
        AMA_ENSURE_MEMORY_ALLOCATED(eventData->name);
    }

    eventData->number_in_session = event.sequenceNumber;
    eventData->time = (uint64_t)event.timeSinceSession;
    eventData->type = (uint32_t)event.type;

    eventData->global_number = event.globalNumber;
    eventData->has_global_number = true;

    eventData->number_of_type = event.numberOfType;
    eventData->has_number_of_type = true;

    eventData->source = [AMAProtoConversionUtility eventSourceToLocalProto:event.source];
    eventData->has_source = true;

    eventData->attribution_id_changed = event.attributionIDChanged;
    eventData->has_attribution_id_changed = true;

    eventData->has_open_id = true;
    if (event.openID != nil) {
        eventData->open_id = event.openID.unsignedLongValue;
    }

    eventData->has_bytes_truncated = event.bytesTruncated > 0;
    eventData->bytes_truncated = (uint32_t)event.bytesTruncated;

    eventData->location_tracking_enabled = [self protobufOptionalBool:event.locationEnabled];
    eventData->has_location_tracking_enabled = true;

    eventData->first_occurrence = [self protobufOptionalBool:event.firstOccurrence];
    eventData->has_first_occurrence = true;

    eventData->has_profile_id = [AMAProtobufUtilities fillBinaryData:&eventData->profile_id
                                                          withString:event.profileID
                                                             tracker:tracker];

    if (event.eventEnvironment != nil) {
        NSString *eventEnvironment = [AMAJSONSerialization stringWithJSONObject:event.eventEnvironment
                                                                          error:NULL];
        eventData->environment = [AMAProtobufUtilities addNSString:eventEnvironment
                                                         toTracker:tracker];
        AMA_ENSURE_MEMORY_ALLOCATED(eventData->environment);
    }

    BOOL result = YES;
    result = result && [self fillEvent:eventData extras:event.extras tracker:tracker error:error];
    result = result && [self fillEvent:eventData withValue:event.value event:event tracker:tracker error:error];
    result = result && [self fillEvent:eventData withLocation:event.location tracker:tracker error:error];
    return result;
}

- (BOOL)fillEvent:(Ama__ReportMessage__Session__Event *)eventData
           extras:(NSDictionary<NSString *, NSData *> *)extras
          tracker:(id<AMAAllocationsTracking>)tracker
            error:(NSError **)error
{
    Ama__ReportMessage__Session__Event__ExtrasEntry **extrasArray = [tracker allocateSize:extras.count * sizeof(Ama__ReportMessage__Session__Event__ExtrasEntry*)];
    __block size_t index = 0;
    __block BOOL result = YES;
    __block NSError *err = nil;

    [extras enumerateKeysAndObjectsUsingBlock:^(NSString *key, id obj, BOOL *stop) {
        Ama__ReportMessage__Session__Event__ExtrasEntry *entry = [tracker allocateSize:sizeof(Ama__ReportMessage__Session__Event__ExtrasEntry)];
        if (entry == nil) {
            *stop = YES;
            result = NO;
            [self fillAllocationError:&err];
            return;
        }
        ama__report_message__session__event__extras_entry__init(entry);

        entry->has_key = [AMAProtobufUtilities fillBinaryData:&entry->key withString:key tracker:tracker];
        entry->has_value = [AMAProtobufUtilities fillBinaryData:&entry->value withData:obj tracker:tracker];

        extrasArray[index] = entry;
        index++;
    }];

    if (result) {
        eventData->extras = extrasArray;
        eventData->n_extras = extras.count;
    }

    *error = err;
    return result;
}

- (BOOL)fillEvent:(Ama__ReportMessage__Session__Event *)eventData
        withValue:(id<AMAEventValueProtocol>)value
            event:(AMAEvent *)event
          tracker:(id<AMAAllocationsTracking>)tracker
            error:(NSError **)error
{
    if (value == nil || value.empty) {
        return YES;
    }
    
    NSError *internalError = nil;
    NSData *data = nil;
    if (eventData->has_encoding_type == NO && [value respondsToSelector:@selector(gzippedDataWithError:)]) {
        data = [value gzippedDataWithError:NULL];
        if (data != nil) {
            eventData->encoding_type = AMA__REPORT_MESSAGE__SESSION__EVENT__ENCODING_TYPE__GZIP;
            eventData->has_encoding_type = YES;
        }
    }
    if (data == nil) {
        data = [value dataWithError:&internalError];
    }
    if (data == nil) {
        AMALogError(@"Failed to collect file data: %@", internalError);
        [self fillError:error withCode:AMAReportSerializerErrorEmpty userInfo:nil];
        [self.delegate reportSerializer:self didFailedToReadFileOfEvent:event];
        return NO;
    }

    eventData->has_value = [AMAProtobufUtilities fillBinaryData:&eventData->value
                                                       withData:data
                                                        tracker:tracker];
    if (eventData->has_value == NO) {
        [self fillAllocationError:error];
        return NO;
    }
    return YES;
}

- (BOOL )fillEvent:(Ama__ReportMessage__Session__Event *)eventData
      withLocation:(CLLocation *)location
           tracker:(id<AMAAllocationsTracking>)tracker
             error:(NSError **)error
{
    if (location == nil || location.horizontalAccuracy < 0) {
        // A negative horizontalAccuracy indicates that the latitude and longitude are invalid.
        return YES;
    }

    Ama__ReportMessage__Location *locationData = [tracker allocateSize:sizeof(Ama__ReportMessage__Location)];
    AMA_ENSURE_MEMORY_ALLOCATED(locationData);
    ama__report_message__location__init(locationData);

    locationData->lat = location.coordinate.latitude;
    locationData->lon = location.coordinate.longitude;

    locationData->has_precision = true;
    locationData->precision = (uint32_t)location.horizontalAccuracy;

    locationData->has_timestamp = true;
    locationData->timestamp = (uint64_t)[location.timestamp timeIntervalSince1970];

#if TARGET_OS_TV
    locationData->has_speed = false;
    locationData->has_direction = false;
#else
    if (location.speed >= 0) {
        locationData->has_speed = true;
        locationData->speed = (uint32_t)location.speed;
    }

    if (location.course >= 0) {
        locationData->has_direction = true;
        locationData->direction = (uint32_t)location.course;
    }
#endif

    if (location.verticalAccuracy >= 0) {
        locationData->has_altitude = true;
        locationData->altitude = (int32_t)location.altitude;
    }

    eventData->location = locationData;
    return YES;
}

#pragma mark - Other report fields

- (BOOL)fillReportMessage:(Ama__ReportMessage *)reportMessage
       withAppEnvironment:(NSDictionary *)appEnvironment
                  tracker:(id<AMAAllocationsTracking>)tracker
                    error:(NSError **)error
{
    if (appEnvironment.count == 0) {
        return YES;
    }
    NSUInteger count = appEnvironment.count;
    reportMessage->app_environment =
        [tracker allocateSize:(sizeof(Ama__ReportMessage__EnvironmentVariable *) * count)];
    AMA_ENSURE_MEMORY_ALLOCATED(reportMessage->app_environment);

    NSUInteger __block index = 0;
    for (NSString *key in appEnvironment) {
        NSString *value = appEnvironment[key];

        Ama__ReportMessage__EnvironmentVariable *variable =
            [tracker allocateSize:sizeof(Ama__ReportMessage__EnvironmentVariable)];
        AMA_ENSURE_MEMORY_ALLOCATED(variable);
        ama__report_message__environment_variable__init(variable);

        variable->name = [AMAProtobufUtilities addNSString:key toTracker:tracker];
        AMA_ENSURE_MEMORY_ALLOCATED(variable->name);
        variable->value = [AMAProtobufUtilities addNSString:value toTracker:tracker];
        AMA_ENSURE_MEMORY_ALLOCATED(variable->value);

        reportMessage->app_environment[index++] = variable;
    }

    reportMessage->n_app_environment = index;
    return YES;
}

- (BOOL)fillReportMessage:(Ama__ReportMessage *)reportMessage
             withAppState:(AMAApplicationState *)appState
                  tracker:(id<AMAAllocationsTracking>)tracker
                    error:(NSError **)error
{
    Ama__RequestParameters *requestParameters = [tracker allocateSize:sizeof(Ama__RequestParameters)];
    AMA_ENSURE_MEMORY_ALLOCATED(requestParameters);
    ama__request_parameters__init(requestParameters);

    requestParameters->device_id = [AMAProtobufUtilities addNSString:appState.deviceID toTracker:tracker];
    AMA_ENSURE_MEMORY_ALLOCATED(requestParameters->device_id);
    requestParameters->uuid = [AMAProtobufUtilities addNSString:appState.UUID toTracker:tracker];
    AMA_ENSURE_MEMORY_ALLOCATED(requestParameters->uuid);

    reportMessage->report_request_parameters = requestParameters;
    return YES;
}

#undef AMA_ENSURE_MEMORY_ALLOCATED

#pragma mark - Enums mapping

- (Ama__ReportMessage__Session__SessionDesc__SessionType)sessionTypeForType:(AMASessionType)sessionType
{
    switch (sessionType) {
        case AMASessionTypeGeneral:
            return AMA__REPORT_MESSAGE__SESSION__SESSION_DESC__SESSION_TYPE__SESSION_FOREGROUND;

        case AMASessionTypeBackground:
            return AMA__REPORT_MESSAGE__SESSION__SESSION_DESC__SESSION_TYPE__SESSION_BACKGROUND;
    }
}

- (Ama__ReportMessage__OptionalBool)protobufOptionalBool:(AMAOptionalBool)optionalBool
{
    switch (optionalBool) {
        case AMAOptionalBoolUndefined:
        default:
            return AMA__REPORT_MESSAGE__OPTIONAL_BOOL__OPTIONAL_BOOL_UNDEFINED;
        case AMAOptionalBoolFalse:
            return AMA__REPORT_MESSAGE__OPTIONAL_BOOL__OPTIONAL_BOOL_FALSE;
        case AMAOptionalBoolTrue:
            return AMA__REPORT_MESSAGE__OPTIONAL_BOOL__OPTIONAL_BOOL_TRUE;
    }
}

#pragma mark - Errors

- (void)fillAllocationError:(NSError **)error
{
    [self fillError:error withCode:AMAReportSerializerErrorAllocationError userInfo:nil];
}

- (void)fillError:(NSError **)error withCode:(AMAReportSerializerErrorCode)code userInfo:(NSDictionary *)userInfo
{
    [AMAErrorUtilities fillError:error withError:[NSError errorWithDomain:kAMAReportSerializerErrorDomain
                                                                    code:code
                                                                userInfo:userInfo]];
}

@end
