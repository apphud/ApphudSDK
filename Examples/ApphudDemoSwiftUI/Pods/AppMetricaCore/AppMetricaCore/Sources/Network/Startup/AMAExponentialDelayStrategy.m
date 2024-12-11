
#import "AMACore.h"
#import "AMAExponentialDelayStrategy.h"
#import "AMAExponentialBackoff.h"

@interface AMAExponentialDelayStrategy()

@property (nonatomic, assign, readonly) NSTimeInterval slotDelayInterval;
@property (nonatomic, strong, readonly) AMAExponentialBackoff *slotIndexGenerator;
@property (nonatomic, strong) NSDate *lastDelayRequestDate;

@end

@implementation AMAExponentialDelayStrategy

- (instancetype)init
{
    return [self initWithSlotDelayInterval:0.1 maxRetryCount:5];
}

- (instancetype)initWithSlotDelayInterval:(NSTimeInterval)slotDelayInterval
                            maxRetryCount:(NSInteger)maxRetryCount
{
    self = [super init];
    if (self != nil) {
        _slotDelayInterval = slotDelayInterval;
        _slotIndexGenerator = [[AMAExponentialBackoff alloc] initWithMaxRetryCount:maxRetryCount];
    }

    return self;
}

- (NSTimeInterval)delay
{
    NSDate *currentDate = [NSDate date];
    NSTimeInterval delay = 0;

    if (self.lastDelayRequestDate != nil) {
        NSTimeInterval delta = [currentDate timeIntervalSinceDate:self.lastDelayRequestDate];
        self.lastDelayRequestDate = currentDate;

        if (self.slotIndexGenerator.maxRetryCountReached) {
            [self.slotIndexGenerator reset];
        }

        delay = [self.slotIndexGenerator next] * self.slotDelayInterval;
        if (delay <= delta) {
            delay = 0;
        }
    }
    else {
        self.lastDelayRequestDate = currentDate;
    }

    return delay;
}

@end
