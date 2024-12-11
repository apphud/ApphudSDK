
#import "AMAMach.h"

@implementation AMAMach

- (instancetype)initWithExceptionType:(int32_t)exceptionType code:(int64_t)code subcode:(int64_t)subcode
{
    self = [super init];
    if (self != nil) {
        _exceptionType = exceptionType;
        _code = code;
        _subcode = subcode;
    }

    return self;
}

@end
