
#import <Foundation/Foundation.h>

@interface AMAApplicationStatistics : NSObject

@property (nonatomic, assign, readonly) BOOL applicationActive;
@property (nonatomic, assign, readonly) BOOL applicationInForeground;
@property (nonatomic, assign, readonly) uint32_t launchesSinceLastCrash;
@property (nonatomic, assign, readonly) uint32_t sessionsSinceLastCrash;
@property (nonatomic, assign, readonly) double activeTimeSinceLastCrash;
@property (nonatomic, assign, readonly) double backgroundTimeSinceLastCrash;
@property (nonatomic, assign, readonly) uint32_t sessionsSinceLaunch;
@property (nonatomic, assign, readonly) double activeTimeSinceLaunch;
@property (nonatomic, assign, readonly) double backgroundTimeSinceLaunch;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithApplicationActive:(BOOL)applicationActive
                  applicationInForeground:(BOOL)applicationInForeground
                   launchesSinceLastCrash:(uint32_t)launchesSinceLastCrash
                   sessionsSinceLastCrash:(uint32_t)sessionsSinceLastCrash
                 activeTimeSinceLastCrash:(double)activeTimeSinceLastCrash
             backgroundTimeSinceLastCrash:(double)backgroundTimeSinceLastCrash
                      sessionsSinceLaunch:(uint32_t)sessionsSinceLaunch
                    activeTimeSinceLaunch:(double)activeTimeSinceLaunch
                backgroundTimeSinceLaunch:(double)backgroundTimeSinceLaunch;


@end
