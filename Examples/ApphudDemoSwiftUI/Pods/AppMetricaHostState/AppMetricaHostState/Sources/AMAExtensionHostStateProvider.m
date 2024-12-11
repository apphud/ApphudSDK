
#import <AppMetricaHostState/AppMetricaHostState.h>
#import "AMAExtensionHostStateProvider.h"

@interface AMAExtensionHostStateProvider ()

@property (atomic) AMAHostAppState internalHostState;

@end

@implementation AMAExtensionHostStateProvider

- (instancetype)init
{
    self = [super init];
    if (self) {
        _internalHostState = AMAHostAppStateBackground;
    }
    return self;

}

- (void)forceUpdateToForeground
{
    [self maybeChangeStateTo:AMAHostAppStateForeground];
}

- (AMAHostAppState)hostState
{
    @synchronized (self) {
        return self.internalHostState;
    }
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
    if (stateChanged) {
        [self hostStateDidChange];
    }
}

@end
