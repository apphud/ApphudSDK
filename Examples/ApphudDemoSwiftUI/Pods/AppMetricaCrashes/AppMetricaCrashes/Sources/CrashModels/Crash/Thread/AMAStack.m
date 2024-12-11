
#import "AMAStack.h"

@implementation AMAStack

- (instancetype)initWithGrowDirection:(AMAGrowDirection)growDirection
                            dumpStart:(uint64_t)dumpStart
                              dumpEnd:(uint64_t)dumpEnd
                         stackPointer:(uint64_t)stackPointer
                             overflow:(BOOL)overflow
                             contents:(NSData *)contents
{
    self = [super init];
    if (self) {
        _growDirection = growDirection;
        _dumpStart = dumpStart;
        _dumpEnd = dumpEnd;
        _stackPointer = stackPointer;
        _overflow = overflow;
        _contents = [contents copy];
    }

    return self;
}

@end
