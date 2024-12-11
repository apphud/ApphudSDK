
#import <AppMetricaHostState/AppMetricaHostState.h>
#import "AMAHostStateControllerFactory.h"
#import "AMAApplicationHostStateProvider.h"
#import "AMAExtensionHostStateProvider.h"
#import "AMAHostStateControlling.h"

@interface AMAHostStateControllerFactory ()

@property (nonatomic, assign, readonly) BOOL isExtension;

@end

@implementation AMAHostStateControllerFactory

- (instancetype)init
{
    return [self initWithBundle:[NSBundle mainBundle]];
}

- (instancetype)initWithBundle:(NSBundle *)bundle
{
    self = [super init];
    if (self) {
        _isExtension = bundle.executablePath.length != 0 &&
            [bundle.executablePath rangeOfString:@".appex"].location != NSNotFound;
    }
    return self;
}

- (id<AMAHostStateControlling>)hostStateController
{
    id<AMAHostStateControlling> hostStateProvider;
    if (self.isExtension) {
        hostStateProvider = [[AMAExtensionHostStateProvider alloc] init];
    }
    else {
        hostStateProvider = [[AMAApplicationHostStateProvider alloc] init];
    }
    return hostStateProvider;
}

@end
