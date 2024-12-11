
#import "AMANonFatal.h"

@implementation AMANonFatal

- (instancetype)initWithModel:(AMAErrorModel *)model backtrace:(AMABacktrace *)backtrace
{
    self = [super init];
    if (self != nil) {
        _model = model;
        _backtrace = backtrace;
    }
    return self;
}

@end
