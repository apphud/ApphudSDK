#import <AppMetricaHostState/AppMetricaHostState.h>
#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>
#import "AMAApplicationHostStateProvider.h"
#import "AMAHostStateControllerFactory.h"

static id<AMAHostStateControlling> hostStateController = nil;

@interface AMAHostStateProvider () <AMAHostStateProviderObserver>

@property (nonatomic, nullable, weak) id<AMAHostStateControlling> hostStateController;

@end

@implementation AMAHostStateProvider

@synthesize delegate = _delegate;

+ (void)load
{
    AMAHostStateControllerFactory *factory = [[AMAHostStateControllerFactory alloc] init];
    hostStateController = [factory hostStateController];
}

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _hostStateController = hostStateController;
        
        [_hostStateController addAMAObserver:self];
    }

    return self;
}

- (AMAHostAppState)hostState
{
    return [self.hostStateController hostState];
}

- (void)forceUpdateToForeground
{
    [self.hostStateController forceUpdateToForeground];
}

- (void)hostStateProviderDidChangeHostState
{
    [self.delegate hostStateDidChange:[self hostState]];
}

- (void)dealloc
{
    [_hostStateController removeAMAObserver:self];
}

@end
