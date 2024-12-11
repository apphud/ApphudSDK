
#import "AMAApplicationStatistics.h"

@implementation AMAApplicationStatistics

- (instancetype)initWithApplicationActive:(BOOL)applicationActive
                  applicationInForeground:(BOOL)applicationInForeground
                   launchesSinceLastCrash:(uint32_t)launchesSinceLastCrash
                   sessionsSinceLastCrash:(uint32_t)sessionsSinceLastCrash
                 activeTimeSinceLastCrash:(double)activeTimeSinceLastCrash
             backgroundTimeSinceLastCrash:(double)backgroundTimeSinceLastCrash
                      sessionsSinceLaunch:(uint32_t)sessionsSinceLaunch
                    activeTimeSinceLaunch:(double)activeTimeSinceLaunch
                backgroundTimeSinceLaunch:(double)backgroundTimeSinceLaunch
{
    self = [super init];
    if (self != nil) {
        _applicationActive = applicationActive;
        _applicationInForeground = applicationInForeground;
        _launchesSinceLastCrash = launchesSinceLastCrash;
        _sessionsSinceLastCrash = sessionsSinceLastCrash;
        _activeTimeSinceLastCrash = activeTimeSinceLastCrash;
        _backgroundTimeSinceLastCrash = backgroundTimeSinceLastCrash;
        _sessionsSinceLaunch = sessionsSinceLaunch;
        _activeTimeSinceLaunch = activeTimeSinceLaunch;
        _backgroundTimeSinceLaunch = backgroundTimeSinceLaunch;
    }

    return self;
}

@end
