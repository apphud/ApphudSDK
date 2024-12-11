
#import "AMAThread.h"
#import "AMABacktrace.h"

@implementation AMAThread

- (instancetype)initWithBacktrace:(AMABacktrace *)backtrace
                        registers:(AMARegistersContainer *)registers
                            stack:(AMAStack *)stack
                            index:(uint32_t)index
                          crashed:(BOOL)crashed
                       threadName:(NSString *)threadName
                        queueName:(NSString *)queueName
{
    self = [super init];
    if (self != nil) {
        _backtrace = backtrace;
        _registers = registers;
        _stack = stack;
        _index = index;
        _crashed = crashed;
        _threadName = [threadName copy];
        _queueName = [queueName copy];
    }

    return self;
}

- (id)copyWithZone:(NSZone *)zone
{
    return [[[self class] alloc] initWithBacktrace:[self.backtrace copy]
                                         registers:self.registers
                                             stack:self.stack
                                             index:self.index
                                           crashed:self.crashed
                                        threadName:[self.threadName copy]
                                         queueName:[self.queueName copy]];
}

@end
