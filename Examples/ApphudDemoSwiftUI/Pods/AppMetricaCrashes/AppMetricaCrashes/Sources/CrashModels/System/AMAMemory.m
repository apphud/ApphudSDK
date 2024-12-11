
#import "AMAMemory.h"

@implementation AMAMemory

- (instancetype)initWithSize:(uint64_t)size usable:(uint64_t)usable free:(uint64_t)free
{
    self = [super init];
    if (self != nil) {
        _size = size;
        _usable = usable;
        _free = free;
    }

    return self;
}

@end
