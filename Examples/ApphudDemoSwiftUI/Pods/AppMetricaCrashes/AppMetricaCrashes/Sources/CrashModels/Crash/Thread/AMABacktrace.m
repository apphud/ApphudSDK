
#import "AMABacktrace.h"
#import "AMABacktraceFrame.h"

@implementation AMABacktrace

- (instancetype)init
{
    return [self initWithFrames:[NSMutableArray array]];
}

- (instancetype)initWithFrames:(NSMutableArray<AMABacktraceFrame *> *)frames
{
    self = [super init];
    if (self != nil) {
        _frames = frames;
    }

    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] initWithFrames:self.frames.mutableCopy];
}

@end
