
#import <Foundation/Foundation.h>

#if TARGET_OS_IOS
@class CLVisit;
#endif
@class CLLocation;
@class AMALocationCollectingConfiguration;
@class AMALocationStorage;
@class AMALocationFilter;
@class AMALocationDispatcher;
@class AMAPersistentTimeoutConfiguration;
@protocol AMACancelableExecuting;
@protocol AMADateProviding;

@interface AMALocationCollectingController : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithConfiguration:(AMALocationCollectingConfiguration *)configuration
                 timeoutConfiguration:(AMAPersistentTimeoutConfiguration *)timeoutConfiguration;

- (instancetype)initWithConfiguration:(AMALocationCollectingConfiguration *)configuration
                              storage:(AMALocationStorage *)storage
                               filter:(AMALocationFilter *)filter
                           dispatcher:(AMALocationDispatcher *)dispatcher
                             executor:(id<AMACancelableExecuting>)executor
                         dateProvider:(id<AMADateProviding>)dateProvider;

- (void)addSystemLocations:(NSArray<CLLocation *> *)locations;
#if TARGET_OS_IOS
- (void)addVisit:(CLVisit *)visit;
#endif

@end
