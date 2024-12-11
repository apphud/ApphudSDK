
#import "AMATimeoutConfiguration.h"

@implementation AMATimeoutConfiguration

- (instancetype)initWithLimitDate:(NSDate *)limitDate count:(NSUInteger)count
{
    self = [super init];
    if (self != nil) {
        _limitDate = limitDate;
        _count = count;
    }

    return self;
}

@end
