
#import <CoreLocation/CoreLocation.h>
#import <AppMetricaPlatform/AppMetricaPlatform.h>
#import "AMACore.h"
#import "AMALocationManager.h"
#import "AMAStartupPermissionController.h"
#import "AMALocationCollectingController.h"
#import "AMALocationCollectingConfiguration.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaPersistentConfiguration.h"

@interface AMALocationManager () <CLLocationManagerDelegate>

@property (nonatomic, strong) CLLocationManager *locationManager;
@property (nonatomic, strong) NSNumber *authorizationStatus;
@property (nonatomic, strong) CLLocation *externalLocation;
@property (nonatomic, assign) BOOL locationManagerStartedInitialization;
@property (nonatomic, assign) BOOL locationUpdateInProgress;

@property (nonatomic, assign) BOOL currentTrackLocationEnabled;
@property (nonatomic, assign) BOOL currentAccurateLocationEnabled;
@property (nonatomic, assign) BOOL currentAllowsBackgroundLocationUpdates;

@property (nonatomic, strong, readonly) id<AMAAsyncExecuting, AMASyncExecuting> executor;
@property (nonatomic, strong, readonly) id<AMAAsyncExecuting> mainQueueExecutor;
@property (nonatomic, strong, readonly) AMAStartupPermissionController *startupPermissionController;
@property (nonatomic, strong, readonly) AMALocationCollectingController *locationCollectingController;
@property (nonatomic, strong, readonly) AMALocationCollectingConfiguration *configuration;

@end

@implementation AMALocationManager

- (instancetype)init
{
    AMAExecutor *executor = [[AMAExecutor alloc] initWithIdentifier:self];
    id<AMAAsyncExecuting> mainQueueExecutor = [[AMAExecutor alloc] initWithQueue:dispatch_get_main_queue()];
    AMAStartupPermissionController *startupPermissionController = [[AMAStartupPermissionController alloc] init];
    AMALocationCollectingConfiguration *configuration = [[AMALocationCollectingConfiguration alloc] init];
    AMAPersistentTimeoutConfiguration *timeoutConfiguration =
        [AMAMetricaConfiguration sharedInstance].persistent.timeoutConfiguration;

    return [self initWithExecutor:executor
                mainQueueExecutor:mainQueueExecutor
      startupPermissionController:startupPermissionController
                    configuration:configuration
     locationCollectingController:[[AMALocationCollectingController alloc] initWithConfiguration:configuration
                                                                            timeoutConfiguration:timeoutConfiguration]];
}

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting, AMASyncExecuting>)executor
               mainQueueExecutor:(id<AMAAsyncExecuting>)mainQueueExecutor
     startupPermissionController:(AMAStartupPermissionController *)startupPermissionController
                   configuration:(AMALocationCollectingConfiguration *)configuration
    locationCollectingController:(AMALocationCollectingController *)locationCollectingController
{
    self = [super init];
    if (self != nil) {
        _executor = executor;
        _mainQueueExecutor = mainQueueExecutor;
        _startupPermissionController = startupPermissionController;
        _configuration = configuration;
        _locationCollectingController = locationCollectingController;
        _currentTrackLocationEnabled = YES;
    }

    return self;
}

#pragma mark - Public -

+ (instancetype)sharedManager
{
    static AMALocationManager *sharedLocationManager = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        sharedLocationManager = [[AMALocationManager alloc] init];
    });
    return sharedLocationManager;
}

- (CLLocation *)currentLocation
{
    CLLocation *currentLocation = nil;
    @synchronized (self) {
        if (self.currentTrackLocationEnabled) {
            if ([self isExternalLocationAvailable]) {
                currentLocation = self.externalLocation;
            }
            else {
                if ([self isLocationSystemPermissionGranted]) {
                    currentLocation = self.locationManager.location;
                }
            }
        }
    }
    AMALogInfo(@"Current location is: %@", currentLocation);
    return currentLocation;
}
#if TARGET_OS_IOS
- (void)sendMockVisit:(CLVisit *)visit
{
    [self locationManager:(CLLocationManager *)[NSObject new] didVisit:visit];
}
#endif

- (void)setLocation:(CLLocation *)location
{
    @synchronized (self) {
        self.externalLocation = location;
    }
    [self.executor execute:^{
        AMALogInfo(@"External location is set: %@", location);
        [self syncUpdateLocationUpdatesForCurrentStatus];
    }];
}

- (CLLocation *)location
{
    CLLocation *result = nil;
    @synchronized (self) {
        result = self.externalLocation;
    }
    return result;
}

- (void)setAccurateLocationEnabled:(BOOL)preciseLocationNeeded
{
    [self.executor execute:^{
        self.currentAccurateLocationEnabled = preciseLocationNeeded;
        [self configureLocationManager];
    }];
}

- (BOOL)accurateLocationEnabled
{
    return [[self.executor syncExecute:^id {
        return @(self.currentAccurateLocationEnabled);
    }] boolValue];
}

- (void)setAllowsBackgroundLocationUpdates:(BOOL)allowsBackgroundLocationUpdates
{
    [self.executor execute:^{
        self.currentAllowsBackgroundLocationUpdates = allowsBackgroundLocationUpdates;
        [self configureLocationManager];
    }];
}

- (BOOL)allowsBackgroundLocationUpdates
{
    return [[self.executor syncExecute:^id {
        return @(self.currentAllowsBackgroundLocationUpdates);
    }] boolValue];
}

- (void)start
{
    [self.executor execute:^{
        [self syncUpdateLocationManagerForCurrentStatus];
    }];
}

- (void)updateAuthorizationStatus
{
    [self.executor execute:^{
        @synchronized (self) {
            [self updateAuthorizationStatusFromLocationManager];
        }
        [self syncUpdateLocationManagerForCurrentStatus];
    }];
}

- (void)updateLocationManagerForCurrentStatus
{
    [self.executor execute:^{
        [self syncUpdateLocationManagerForCurrentStatus];
    }];
}

- (BOOL)trackLocationEnabled
{
    @synchronized (self) {
        return self.currentTrackLocationEnabled;
    }
}

- (void)setTrackLocationEnabled:(BOOL)locationTrackingEnabled
{
    @synchronized (self) {
        self.currentTrackLocationEnabled = locationTrackingEnabled;
    }
    [self.executor execute:^{
        AMALogInfo(@"Location tracking flag is changed to: %@", locationTrackingEnabled ? @"YES" : @"NO");
        [self syncUpdateLocationManagerForCurrentStatus];
    }];
}

#pragma mark - Private -

- (CLAuthorizationStatus)currentAuthorizationStatus {
    CLAuthorizationStatus authorizationStatus = kCLAuthorizationStatusNotDetermined;
    @synchronized (self) {
        // wait for change authorizationStatus via delegate
        if (self.authorizationStatus != nil) {
            authorizationStatus = (CLAuthorizationStatus)[self.authorizationStatus intValue];
        }
    }
    return authorizationStatus;
}

- (BOOL)isLocationSystemPermissionGranted
{
    CLAuthorizationStatus authorizationStatus = [self currentAuthorizationStatus];
    BOOL result = authorizationStatus == kCLAuthorizationStatusAuthorizedWhenInUse ||
                  authorizationStatus == kCLAuthorizationStatusAuthorizedAlways;
    return result;
}

- (BOOL)isVisitsSystemPermissionGranted
{
    return [self currentAuthorizationStatus] == kCLAuthorizationStatusAuthorizedAlways;
}

- (BOOL)isExternalLocationAvailable
{
    @synchronized (self) {
        return self.externalLocation != nil;
    }
}

- (BOOL)isLocationCollectingGranted
{
    BOOL result = [self.startupPermissionController isLocationCollectingGranted];
    AMALogInfo(@"isLocationCollectingGranted: %d", result);
    return result;
}

- (void)logPreventionOfAction:(NSString *)action reason:(NSString *)reason
{
    AMALogInfo(@"Location %@ prevented: %@", action, reason);
}

- (BOOL)shouldUseLocationManagerForAction:(NSString *)action
{
    BOOL result = NO;
    if ([self isExternalLocationAvailable]) {
        [self logPreventionOfAction:action reason:@"external location is available"];
    }
    else if (self.currentTrackLocationEnabled == NO) {
        [self logPreventionOfAction:action reason:@"location tracking is disabled"];
    }
    else if ([self isLocationCollectingGranted] == NO) {
        [self logPreventionOfAction:action reason:@"location collecting is forbidden"];
    }
    else {
        result = YES;
    }
    return result;
}

- (BOOL)shouldInitializeLocationManager
{
    BOOL result = NO;
    NSString *action = @"initialization";
    if (self.locationManager != nil) {
        [self logPreventionOfAction:action reason:@"already initialized"];
    }
    else if ([self shouldUseLocationManagerForAction:action] == NO) {
        // Already logged
    }
    else {
        result = YES;
    }
    return result;
}

- (BOOL)shouldStartLocationUpdates
{
    BOOL result = NO;
    NSString *action = @"start";
    if ([self isLocationManagerAvailableForAction:action] == NO) {
        // Already logged
    }
    else if ([self isLocationSystemPermissionGranted] == NO) {
        [self logPreventionOfAction:action reason:@"location permission is not granted"];
    }
    else {
        result = YES;
    }
    return result;
}

- (BOOL)shouldStartVisitsMonitoring
{
    BOOL result = NO;
    NSString *action = @"visits";
    if ([self isLocationManagerAvailableForAction:action] == NO) {
        // Already logged
    }
    else if ([self isVisitsSystemPermissionGranted] == NO) {
        [self logPreventionOfAction:action reason:@"always system permission for visits is not granted"];
    }
    else if (self.configuration.visitsCollectingEnabled == NO) {
        [self logPreventionOfAction:action reason:@"visit monitoring is not granted in startup"];
    }
    else {
        result = YES;
    }
    return result;
}

- (BOOL)isLocationManagerAvailableForAction:(NSString *)action
{
    BOOL result = NO;
    if (self.locationManagerStartedInitialization == NO) {
        [self logPreventionOfAction:action reason:@"location manager is not initialized"];
    }
    else if ([self shouldUseLocationManagerForAction:action] == NO) {
        // Already logged
    }
    else {
        result = YES;
    }
    return result;
}

- (void)syncUpdateLocationManagerForCurrentStatus
{
    [self syncUpdateLocationUpdatesForCurrentStatus];
    [self syncUpdateVisitsMonitoringForCurrentStatus];
}

- (void)syncUpdateLocationUpdatesForCurrentStatus
{
    [self initLocationManagerIfNeeded];
    if ([self shouldStartLocationUpdates]) {
        [self startLocationUpdates];
    }
    else {
        [self stopLocationUpdates];
    }
}

- (void)syncUpdateVisitsMonitoringForCurrentStatus
{
    [self initLocationManagerIfNeeded];
    if ([self shouldStartVisitsMonitoring]) {
        [self startVisitsMonitoring];
    }
    else {
        [self stopVisitsMonitoring];
    }
}

- (void)initLocationManagerIfNeeded
{
    if ([self shouldInitializeLocationManager]) {
        [self initializeLocationManager];
    }
}

- (void)initializeLocationManager
{
    if (self.locationManagerStartedInitialization == NO) {
        @synchronized (self) {
            if (self.locationManagerStartedInitialization == NO) {
                self.locationManagerStartedInitialization = YES;

                __weak __typeof(self) weakSelf = self;

                [self.mainQueueExecutor execute:^{
                    __strong __typeof(weakSelf) strongSelf = weakSelf;

                    CLLocationManager *manager = [[CLLocationManager alloc] init];
                    AMALogInfo(@"location manager is created: %@", manager);

                    strongSelf.locationManager = manager;
                    strongSelf.locationManager.delegate = strongSelf;
                }];
            }
        }
    }
}

- (void)updateAuthorizationStatusFromLocationManager {
    if (@available(iOS 14.0, tvOS 14.0, *)) {
        if (self.locationManager != nil) {
            @synchronized (self) {
                self.authorizationStatus = @(self.locationManager.authorizationStatus);
            }
        }
    }
    else {
        @synchronized (self) {
            self.authorizationStatus = @([CLLocationManager authorizationStatus]);
        }
    }
}

- (void)startLocationUpdates
{
    if (self.locationUpdateInProgress) {
        return;
    }

    self.locationUpdateInProgress = YES;
    [self.mainQueueExecutor execute:^{
        AMALogInfo(@"Start location manager");
        [self configureLocationManager];
#if TARGET_OS_TV
        [self.locationManager requestLocation];
#else
        [self.locationManager startUpdatingLocation];
#endif
    }];
}

- (void)stopLocationUpdates
{
    self.locationUpdateInProgress = NO;
    [self.mainQueueExecutor execute:^{
        AMALogInfo(@"Stop location manager");
        [self.locationManager stopUpdatingLocation];
    }];
}

- (void)startVisitsMonitoring
{
#if TARGET_OS_IOS
    [self.mainQueueExecutor execute:^{
        AMALogInfo(@"Start monitoring visits");
        [self.locationManager startMonitoringVisits];
    }];
#endif
}

- (void)stopVisitsMonitoring
{
#if TARGET_OS_IOS
    [self.mainQueueExecutor execute:^{
        AMALogInfo(@"Stop monitoring visits");
        [self.locationManager stopMonitoringVisits];
    }];
#endif
}

- (void)configureLocationManager
{
    if (self.currentAccurateLocationEnabled) {
        AMALogInfo(@"Use accurate location");
        self.locationManager.desiredAccuracy = self.configuration.accurateDesiredAccuracy;
        self.locationManager.distanceFilter = self.configuration.accurateDistanceFilter;
    }
    else {
        self.locationManager.desiredAccuracy = self.configuration.defaultDesiredAccuracy;
        self.locationManager.distanceFilter = self.configuration.defaultDistanceFilter;
    }

#if !TARGET_OS_TV
    if ([AMAPlatformDescription isExtension] == NO) {
        self.locationManager.pausesLocationUpdatesAutomatically = self.configuration.pausesLocationUpdatesAutomatically;
    }
    AMALogInfo(@"Allow background location updates");
    self.locationManager.allowsBackgroundLocationUpdates = self.currentAllowsBackgroundLocationUpdates;
#endif
}

#pragma mark - CLLocationManagerDelegate -

- (void)locationManager:(CLLocationManager *)manager didChangeAuthorizationStatus:(CLAuthorizationStatus)status
{
    AMALogInfo(@"Authorization status changed to %d", status);
    [self updateAuthorizationStatusFromLocationManager];
    [self updateLocationManagerForCurrentStatus];
}

- (void)locationManagerDidChangeAuthorization:(CLLocationManager *)manager API_AVAILABLE(ios(14.0), macos(11.0), watchos(7.0), tvos(14.0))
{
    AMALogInfo(@"Authorization status changed to %d", manager.authorizationStatus);
    [self updateAuthorizationStatusFromLocationManager];
    [self updateLocationManagerForCurrentStatus];
}

- (void)locationManager:(CLLocationManager *)manager didUpdateLocations:(NSArray *)locations
{
    AMALogInfo(@"Location updated with %@", locations.lastObject);
    [self.locationCollectingController addSystemLocations:locations];
}

- (void)locationManager:(CLLocationManager *)manager didFailWithError:(NSError *)error
{
    AMALogInfo(@"Failed to retrieve location with error: %@", error);
}
#if TARGET_OS_IOS
- (void)locationManager:(CLLocationManager *)manager didVisit:(CLVisit *)visit
{
    AMALogInfo(@"Visit captured: %@", visit);
    [self.locationCollectingController addVisit:visit];
}
#endif
@end
