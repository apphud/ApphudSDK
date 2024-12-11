
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>
#import <CoreLocation/CoreLocation.h>
#import "AMACore.h"
#import "LocationMessage.pb-c.h"
#import "AMALocationSerializer.h"
#import "AMALocation.h"
#import "AMAVisit.h"

@implementation AMALocationSerializer

#pragma mark - Public -

- (NSData *)dataForLocations:(NSArray<AMALocation *> *)locations visits:(NSArray<AMAVisit *> *)visits
{
    NSData *__block packedMessage = nil;
    [AMAAllocationsTrackerProvider track:^(id<AMAAllocationsTracking> tracker) {
        Ama__LocationMessage locationMessage = AMA__LOCATION_MESSAGE__INIT;

        locationMessage.n_location = locations.count;
        locationMessage.location = [tracker allocateSize:sizeof(Ama__LocationMessage__Location *) * locations.count];
        [locations enumerateObjectsUsingBlock:^(AMALocation *location, NSUInteger idx, BOOL *stop) {
            Ama__LocationMessage__Location *locationModel = [self protobufLocationForLocation:location tracker:tracker];
            locationMessage.location[idx] = locationModel;
        }];

        locationMessage.n_visits = visits.count;
        locationMessage.visits = [tracker allocateSize:sizeof(Ama__LocationMessage__Visit *) * visits.count];
        [visits enumerateObjectsUsingBlock:^(AMAVisit *visit, NSUInteger idx, BOOL *stop) {
            locationMessage.visits[idx] = [self protobufVisitForVisit:visit tracker:tracker];
        }];

        packedMessage = [self packedDataForLocationMessage:&locationMessage];
    }];
    return packedMessage;
}

- (NSData *)dataForLocations:(NSArray<AMALocation *> *)locations
{
    return [self dataForLocations:locations visits:nil];
}

- (Ama__LocationMessage__Location *)protobufLocationForLocation:(AMALocation *)location
                                                        tracker:(id<AMAAllocationsTracking>)tracker
{
    Ama__LocationMessage__Location *locationModel = [tracker allocateSize:sizeof(Ama__LocationMessage__Location)];
    ama__location_message__location__init(locationModel);

    locationModel->incremental_id = [location.identifier unsignedLongLongValue];
    locationModel->collect_timestamp = (uint64_t)[location.collectDate timeIntervalSince1970];
    if (location.location.timestamp != nil) {
        locationModel->timestamp = (uint64_t)[location.location.timestamp timeIntervalSince1970];
        locationModel->has_timestamp = true;
    }
    locationModel->latitude = location.location.coordinate.latitude;
    locationModel->longitude = location.location.coordinate.longitude;
    if (location.location.horizontalAccuracy >= 0) {
        locationModel->precision = (uint32_t)location.location.horizontalAccuracy;
        locationModel->has_precision = true;
    }
#if !TARGET_OS_TV
    if (location.location.course >= 0) {
        locationModel->direction = (uint32_t)location.location.course;
        locationModel->has_direction = true;
    }
    if (location.location.speed >= 0) {
        locationModel->speed = (uint32_t)location.location.speed;
        locationModel->has_speed = true;
    }
#endif
    locationModel->altitude = (int32_t)location.location.altitude;
    locationModel->has_altitude = true;
    locationModel->provider = [self protobufProviderForProvider:location.provider];
    locationModel->has_provider = true;

    return locationModel;
}

- (NSArray<AMALocation *> *)locationsForData:(NSData *)data
{
    if (data.length == 0) {
        return nil;
    }
    NSMutableArray *locations = nil;
    NS_VALID_UNTIL_END_OF_SCOPE AMAProtobufAllocator *allocator = [[AMAProtobufAllocator alloc] init];
    Ama__LocationMessage *locationMessage =
        ama__location_message__unpack([allocator protobufCAllocator], data.length, data.bytes);

    if (locationMessage != NULL) {
        locations = [NSMutableArray arrayWithCapacity:locationMessage->n_location];
        for (NSUInteger idx = 0; idx < locationMessage->n_location; ++idx) {
            Ama__LocationMessage__Location *locationModel = locationMessage->location[idx];
            AMALocation *location = [self locationForProtobufLocation:locationModel];
            [locations addObject:location];
        }
    }
    else {
        AMALogError(@"Failed to unpack location message with locations");
    }

    return locations;
}

- (NSData *)dataForVisits:(NSArray<AMAVisit *> *)visits;
{
    return [self dataForLocations:nil visits:visits];
}

- (NSArray<AMAVisit *> *)visitsForData:(NSData *)data
{
    if (data.length == 0) {
        return nil;
    }
    NSMutableArray *visits = nil;
    NS_VALID_UNTIL_END_OF_SCOPE AMAProtobufAllocator *allocator = [[AMAProtobufAllocator alloc] init];
    Ama__LocationMessage *locationMessage =
        ama__location_message__unpack([allocator protobufCAllocator], data.length, data.bytes);

    if (locationMessage != NULL) {
        visits = [NSMutableArray arrayWithCapacity:locationMessage->n_visits];
        for (NSUInteger idx = 0; idx < locationMessage->n_visits; ++idx) {
            Ama__LocationMessage__Visit *visitModel = locationMessage->visits[idx];
            AMAVisit *visit = [self visitForProtobufVisit:visitModel];
            [visits addObject:visit];
        }
    }
    else {
        AMALogError(@"Failed to unpack location message with visits");
    }

    return visits;
}

#pragma mark - Private -

- (Ama__LocationProvider)protobufProviderForProvider:(AMALocationProvider)provider
{
    switch (provider) {
        case AMALocationProviderUnknown:
        default:
            return AMA__LOCATION_PROVIDER__PROVIDER_UNKNOWN;

        case AMALocationProviderGPS:
            return AMA__LOCATION_PROVIDER__PROVIDER_GPS;
    }
}

- (NSData *)packedDataForLocationMessage:(Ama__LocationMessage *)message
{
    size_t dataSize = ama__location_message__get_packed_size(message);
    void *buffer = malloc(dataSize);
    ama__location_message__pack(message, buffer);
    return [NSData dataWithBytesNoCopy:buffer length:dataSize];
}

- (AMALocation *)locationForProtobufLocation:(const Ama__LocationMessage__Location *)locationModel
{
    CLLocationCoordinate2D coordinate = CLLocationCoordinate2DMake(locationModel->latitude, locationModel->longitude);
    CLLocationDistance altitude = 0.0;
    if (locationModel->has_altitude) {
        altitude = locationModel->altitude;
    }
    CLLocationAccuracy accuracy = -1.0;
    if (locationModel->has_precision) {
        accuracy = locationModel->precision;
    }
    CLLocationDirection course = -1.0;
    CLLocationSpeed speed = -1.0;
#if !TARGET_OS_TV
    if (locationModel->has_direction) {
        course = locationModel->direction;
    }
    if (locationModel->has_speed) {
        speed = locationModel->speed;
    }
#endif
    NSDate *timestamp = nil;
    if (locationModel->has_timestamp) {
        timestamp = [NSDate dateWithTimeIntervalSince1970:locationModel->timestamp];
    }
    CLLocation *cllocation = [[CLLocation alloc] initWithCoordinate:coordinate
                                                           altitude:altitude
                                                 horizontalAccuracy:accuracy
                                                   verticalAccuracy:-1.0
                                                             course:course
                                                              speed:speed
                                                          timestamp:timestamp];

    NSNumber *identifier = [NSNumber numberWithUnsignedLongLong:locationModel->incremental_id];
    NSDate *collectDate = [NSDate dateWithTimeIntervalSince1970:locationModel->collect_timestamp];
    AMALocationProvider provider = AMALocationProviderUnknown;
    if (locationModel->has_provider) {
        provider = [self providerForProtobufProvider:locationModel->provider];
    }
    AMALocation *location = [[AMALocation alloc] initWithIdentifier:identifier
                                                        collectDate:collectDate
                                                           location:cllocation
                                                           provider:provider];
    return location;
}

- (AMALocationProvider)providerForProtobufProvider:(Ama__LocationProvider)provider
{
    switch (provider) {
        case AMA__LOCATION_PROVIDER__PROVIDER_UNKNOWN:
        default:
            return AMALocationProviderUnknown;

        case AMA__LOCATION_PROVIDER__PROVIDER_GPS:
            return AMALocationProviderGPS;
    }
}

- (Ama__LocationMessage__Visit *)protobufVisitForVisit:(AMAVisit *)visit tracker:(id<AMAAllocationsTracking>)tracker
{
    Ama__LocationMessage__Visit *visitModel = [tracker allocateSize:sizeof(Ama__LocationMessage__Visit)];
    ama__location_message__visit__init(visitModel);
    
    visitModel->has_incremental_id = true;
    visitModel->incremental_id = visit.identifier.unsignedLongLongValue;
    
    visitModel->has_collect_timestamp = true;
    visitModel->collect_timestamp = (uint64_t)visit.collectDate.timeIntervalSince1970;
    
    if (visit.arrivalDate != nil) {
        visitModel->arrival_timestamp = (uint64_t)visit.arrivalDate.timeIntervalSince1970;
        visitModel->has_arrival_timestamp = true;
    }
    if (visit.departureDate != nil) {
        visitModel->departure_timestamp = (uint64_t)visit.departureDate.timeIntervalSince1970;
        visitModel->has_departure_timestamp = true;
    }
    
    visitModel->has_latitude = true;
    visitModel->latitude = visit.latitude;
    
    visitModel->has_longitude = true;
    visitModel->longitude = visit.longitude;
    
    if (visit.precision >= 0) {
        visitModel->precision = visit.precision;
        visitModel->has_precision = true;
    }
    
    return visitModel;
}

- (AMAVisit *)visitForProtobufVisit:(Ama__LocationMessage__Visit *)visitModel
{
    NSNumber *identifier = @(visitModel->incremental_id);
    NSDate *collectDate = [NSDate dateWithTimeIntervalSince1970:visitModel->collect_timestamp];
    NSDate *arrivalDate = nil;
    if (visitModel->has_arrival_timestamp) {
        arrivalDate = [NSDate dateWithTimeIntervalSince1970:visitModel->arrival_timestamp];
    }
    NSDate *departureDate = nil;
    if (visitModel->has_departure_timestamp) {
        departureDate = [NSDate dateWithTimeIntervalSince1970:visitModel->departure_timestamp];
    }
    double latitude = visitModel->latitude;
    double longitude = visitModel->longitude;
    double precision = -1.0;
    if (visitModel->has_precision) {
        precision = visitModel->precision;
    }
    
    return [AMAVisit visitWithIdentifier:identifier
                             collectDate:collectDate
                             arrivalDate:arrivalDate
                           departureDate:departureDate
                                latitude:latitude
                               longitude:longitude
                               precision:precision];
}

@end
