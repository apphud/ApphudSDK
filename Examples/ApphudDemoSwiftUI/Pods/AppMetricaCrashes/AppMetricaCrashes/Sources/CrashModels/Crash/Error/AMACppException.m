
#import "AMACppException.h"

@implementation AMACppException

- (instancetype)initWithName:(NSString *)name
{
    self = [super init];
    if (self != nil) {
        _name = [name copy];
    }

    return self;
}

@end
