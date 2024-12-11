
#import "AMACore.h"
#import <CoreLocation/CoreLocation.h>
#import "AMALocationCollectingController.h"
#import "AMALocation.h"
#import "AMALocationStorage.h"
#import "AMALocationFilter.h"
#import "AMALocationCollectingConfiguration.h"
#import "AMALocationDispatcher.h"
#import "AMATimeoutRequestsController.h"
#import "AMAVisit.h"

@interface AMALocationCollectingController ()

@property (nonatomic, strong, readonly) AMALocationCollectingConfiguration *configuration;
@property (nonatomic, strong, readonly) AMALocationFilter *filter;
@property (nonatomic, strong, readonly) AMALocationStorage *storage;
@property (nonatomic, strong, readonly) AMALocationDispatcher *dispatcher;
@property (nonatomic, strong, readonly) id<AMADateProviding> dateProvider;
@property (nonatomic, strong, readonly) id<AMACancelableExecuting> executor;

@end

@implementation AMALocationCollectingController

- (instancetype)initWithConfiguration:(AMALocationCollectingConfiguration *)configuration
                 timeoutConfiguration:(AMAPersistentTimeoutConfiguration *)timeoutConfiguration
{
    AMALocationStorage *storage = [[AMALocationStorage alloc] initWithConfiguration:configuration];
    id<AMACancelableExecuting> executor = [[AMACancelableDelayedExecutor alloc] initWithIdentifier:self];
    AMATimeoutRequestsController *timeoutController =
        [[AMATimeoutRequestsController alloc] initWithHostType:AMALocationHostType
                                                 configuration:timeoutConfiguration];

    AMALocationDispatcher *dispatcher = [[AMALocationDispatcher alloc] initWithStorage:storage
                                                                         configurtaion:configuration
                                                                              executor:executor
                                                                     timeoutController:timeoutController];
    return [self initWithConfiguration:configuration
                               storage:storage
                                filter:[[AMALocationFilter alloc] initWithConfiguration:configuration]
                            dispatcher:dispatcher
                              executor:executor
                          dateProvider:[[AMADateProvider alloc] init]];
}

- (instancetype)initWithConfiguration:(AMALocationCollectingConfiguration *)configuration
                              storage:(AMALocationStorage *)storage
                               filter:(AMALocationFilter *)filter
                           dispatcher:(AMALocationDispatcher *)dispatcher
                             executor:(id<AMACancelableExecuting>)executor
                         dateProvider:(id<AMADateProviding>)dateProvider
{
    self = [super init];
    if (self != nil) {
        _configuration = configuration;
        _storage = storage;
        _filter = filter;
        _dispatcher = dispatcher;
        _executor = executor;
        _dateProvider = dateProvider;
    }
    return self;
}

#pragma mark - Public -

- (void)addSystemLocations:(NSArray<CLLocation *> *)locations
{
    if (locations.count == 0) {
        AMALogInfo(@"There is no system location to add");
        return;
    }
    [self asyncAddLocations:locations provider:AMALocationProviderGPS];
}
#if TARGET_OS_IOS
- (void)addVisit:(CLVisit *)visit
{
    if (visit == nil) {
        AMALogInfo(@"There is no system visit to add");
        return;
    }
    [self asyncAddVisit:visit];
}
#endif

#pragma mark - Private -

- (void)asyncAddLocations:(NSArray<CLLocation *> *)locations provider:(AMALocationProvider)provider
{
    NSDate *date = self.dateProvider.currentDate;
    __weak __typeof(self) weakSelf = self;
    [self.executor execute:^{
        [weakSelf addLocations:locations provider:provider date:date];
    }];
}

- (void)addLocations:(NSArray<CLLocation *> *)locations provider:(AMALocationProvider)provider date:(NSDate *)date
{
    if (self.configuration.collectingEnabled == NO) {
        AMALogInfo(@"Location collecting is disabled");
        return;
    }

    NSMutableArray *locationModels = [NSMutableArray arrayWithCapacity:locations.count];
    for (CLLocation *location in locations) {
        AMALogInfo(@"Received a location: %@", location);
        if ([self.filter shouldAddLocation:location atDate:date]) {
            AMALocation *locationModel = [[AMALocation alloc] initWithIdentifier:nil
                                                                     collectDate:date
                                                                        location:location
                                                                        provider:provider];
            [locationModels addObject:locationModel];
            [self.filter updateLastLocation:location atDate:date];
        }
        else {
            AMALogInfo(@"Location ignored");
        }
    }

    if (locationModels.count != 0) {
        [self.storage addLocations:[locationModels copy]];
        [self.dispatcher handleLocationAdd];
    }
    else {
        AMALogInfo(@"No location to add");
    }
}
#if TARGET_OS_IOS
- (void)asyncAddVisit:(CLVisit *)visit
{
    if (self.configuration.visitsCollectingEnabled == NO) {
        AMALogInfo(@"Visit monitoring is disabled");
        return;
    }

    NSDate *date = self.dateProvider.currentDate;
    NSDate *arrivalDate = [visit.arrivalDate isEqualToDate:NSDate.distantPast] ? nil : visit.arrivalDate;
    NSDate *departureDate = [visit.departureDate isEqualToDate:NSDate.distantFuture] ? nil : visit.departureDate;
    
    [self.executor execute:^{
        AMALogInfo(@"Received a visit: %@", visit);
        AMAVisit *visitModel = [AMAVisit visitWithIdentifier:nil
                                                 collectDate:date
                                                 arrivalDate:arrivalDate
                                               departureDate:departureDate
                                                    latitude:visit.coordinate.latitude
                                                   longitude:visit.coordinate.longitude
                                                   precision:visit.horizontalAccuracy];

        [self.storage addVisit:visitModel];
        [self.dispatcher handleVisitAdd];
    }];
}
#endif
@end
