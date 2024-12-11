
#import "AMANSException.h"

@implementation AMANSException

- (instancetype)initWithName:(NSString *)name userInfo:(NSString *)userInfo
{
    self = [super init];
    if (self != nil) {
        _name = [name copy];
        _userInfo = [userInfo copy];
    }

    return self;
}

@end
