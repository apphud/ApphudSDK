
#import "AMAExponentialBackoff.h"

static NSInteger const kAMAExponentialBackoffMaxRetryCount = 31;

@interface AMAExponentialBackoff()

@property (nonatomic, assign, readonly) NSInteger maxRetryCount;
@property (nonatomic, assign) NSInteger retryCount;
@property (nonatomic, assign) NSInteger maxSlotIndex;

@end

@implementation AMAExponentialBackoff

@dynamic maxRetryCountReached;

- (instancetype)init
{
     return [self initWithMaxRetryCount:kAMAExponentialBackoffMaxRetryCount];
}

- (instancetype)initWithMaxRetryCount:(NSInteger)maxRetryCount
{
    self = [super init];
    if (self != nil) {
        if (maxRetryCount > 0 && maxRetryCount <= kAMAExponentialBackoffMaxRetryCount) {
            _maxRetryCount = maxRetryCount;
        } else {
            _maxRetryCount = kAMAExponentialBackoffMaxRetryCount;
        }

        [self reset];
    }

    return self;
}

- (BOOL)maxRetryCountReached
{
    return self.retryCount == self.maxRetryCount;
}

- (NSInteger)next
{
    if (self.retryCount < self.maxRetryCount) {
        self.maxSlotIndex = self.maxSlotIndex << 1;
        self.retryCount ++;
    }

    return (NSInteger)arc4random_uniform((uint32_t)self.maxSlotIndex);
}

- (void)reset
{
    self.maxSlotIndex = 1;
    self.retryCount = 0;
}

@end
