
#import "AMASignal.h"

@implementation AMASignal

- (instancetype)initWithSignal:(int32_t)signal code:(int32_t)code
{
    self = [super init];
    if (self != nil) {
        _signal = signal;
        _code = code;
    }

    return self;
}

@end
