
#import <Foundation/Foundation.h>

@class AMABacktrace;
@class AMARegistersContainer;
@class AMAStack;

@interface AMAThread : NSObject <NSCopying>

@property (nonatomic, strong, readonly) AMABacktrace *backtrace;
@property (nonatomic, strong, readonly) AMARegistersContainer *registers;
@property (nonatomic, strong, readonly) AMAStack *stack;
@property (nonatomic, assign, readonly) uint32_t index;
@property (nonatomic, assign, readonly) BOOL crashed;
@property (nonatomic, copy, readonly) NSString *threadName;
@property (nonatomic, copy, readonly) NSString *queueName;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithBacktrace:(AMABacktrace *)backtrace
                        registers:(AMARegistersContainer *)registers
                            stack:(AMAStack *)stack
                            index:(uint32_t)index
                          crashed:(BOOL)crashed
                       threadName:(NSString *)threadName
                        queueName:(NSString *)queueName;
@end
