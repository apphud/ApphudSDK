
#import <Foundation/Foundation.h>
#import <CoreLocation/CoreLocation.h>

@protocol AMAAsyncExecuting;
@protocol AMASyncExecuting;
@class AMAStartupPermissionController;
@class AMALocationCollectingController;
@class AMALocationCollectingConfiguration;

@interface AMALocationManager : NSObject

@property (nonatomic, assign) BOOL trackLocationEnabled;
@property (nonatomic, assign) BOOL accurateLocationEnabled;
@property (nonatomic, assign) BOOL allowsBackgroundLocationUpdates;
@property (nonatomic, strong) CLLocation *location;

+ (instancetype)sharedManager;

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting, AMASyncExecuting>)executor
               mainQueueExecutor:(id<AMAAsyncExecuting>)mainQueueExecutor
     startupPermissionController:(AMAStartupPermissionController *)startupPermissionController
                   configuration:(AMALocationCollectingConfiguration *)configuration
    locationCollectingController:(AMALocationCollectingController *)locationCollectingController;

- (CLLocation *)currentLocation;
#if TARGET_OS_IOS
- (void)sendMockVisit:(CLVisit *)visit;
# endif

- (void)start;
- (void)updateAuthorizationStatus;
- (void)updateLocationManagerForCurrentStatus;

@end
