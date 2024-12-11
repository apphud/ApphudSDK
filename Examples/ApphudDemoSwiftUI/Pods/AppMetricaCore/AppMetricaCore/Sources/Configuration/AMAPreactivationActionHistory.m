
#import "AMAPreactivationActionHistory.h"
#import "AMAEnvironmentContainerActionHistory.h"

@implementation AMAPreactivationActionHistory

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _appEnvironment = [[AMAEnvironmentContainerActionHistory alloc] init];
        _userProfileID = nil;
    }
    return self;
}

@end
