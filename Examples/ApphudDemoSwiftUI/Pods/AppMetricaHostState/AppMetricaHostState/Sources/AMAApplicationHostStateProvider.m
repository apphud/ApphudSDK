
#import <AppMetricaHostState/AppMetricaHostState.h>
#import <UIKit/UIKit.h>
#import "AMAApplicationHostStateProvider.h"
#import "AMAHostStateLogging.h"

@interface AMAApplicationHostStateProvider ()

@property (atomic) AMAHostAppState internalHostState;
@property (nonatomic, strong) NSNotificationCenter *notificationCenter;

@end

@implementation AMAApplicationHostStateProvider

- (void)dealloc
{
    [self.notificationCenter removeObserver:self];
}

- (instancetype)init
{
    return [self initWithNotificationCenter:[NSNotificationCenter defaultCenter]];
}

- (instancetype)initWithNotificationCenter:(NSNotificationCenter *)center
{
    self = [super init];
    if (self) {
        _internalHostState = AMAHostAppStateUnknown;
        _notificationCenter = center;

        [self subscribeToNotifications];
    }

    return self;
}

- (void)subscribeToNotifications
{
    [self.notificationCenter addObserver:self
                                selector:@selector(applicationDidBecomeActive)
                                    name:UIApplicationDidBecomeActiveNotification
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(applicationWillResignActive)
                                    name:UIApplicationWillResignActiveNotification
                                  object:nil];

    [self.notificationCenter addObserver:self
                                selector:@selector(applicationWillTerminate)
                                    name:UIApplicationWillTerminateNotification
                                  object:nil];
}

- (void)forceUpdateToForeground
{
    [self maybeChangeStateTo:AMAHostAppStateForeground];
}

- (AMAHostAppState)hostState
{
    @synchronized (self) {
        return self.internalHostState == AMAHostAppStateUnknown ? AMAHostAppStateBackground : self.internalHostState;
    }
}

- (void)applicationDidBecomeActive
{
    [self maybeChangeStateTo:AMAHostAppStateForeground];
}

- (void)applicationWillResignActive
{
    [self maybeChangeStateTo:AMAHostAppStateBackground];
}

- (void)applicationWillTerminate
{
    [self maybeChangeStateTo:AMAHostAppStateTerminated];
}

#pragma mark - Private

- (void)maybeChangeStateTo:(AMAHostAppState)newState
{
    BOOL stateChanged = NO;
    if (self.internalHostState != newState) {
        @synchronized (self) {
            if (self.internalHostState != newState) {
                self.internalHostState = newState;
                stateChanged = YES;
            }
        }
    }
    AMALogInfo(@"Application state is now %@. State changed: %d", [self getDescriptionForState:newState], stateChanged);
    if (stateChanged) {
        [self hostStateDidChange];
    }
}

- (NSString *)getDescriptionForState:(AMAHostAppState)state
{
    switch (state) {
        case AMAHostAppStateForeground:
            return @"foreground";
        case AMAHostAppStateBackground:
            return @"background";
        case AMAHostAppStateTerminated:
            return @"terminated";
        case AMAHostAppStateUnknown:
        default:
            return @"unknown";
    }
}

@end
