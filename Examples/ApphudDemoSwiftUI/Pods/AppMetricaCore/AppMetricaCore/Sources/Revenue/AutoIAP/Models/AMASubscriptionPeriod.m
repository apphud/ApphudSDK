
#import "AMASubscriptionPeriod.h"

@implementation AMASubscriptionPeriod

- (instancetype)initWithCount:(NSUInteger)count timeUnit:(AMATimeUnit)timeUnit
{
    self = [super init];
    if (self != nil) {
        _count = count;
        _timeUnit = timeUnit;
    }
    return self;
}

-(BOOL)isEqual:(AMASubscriptionPeriod *)object
{
    if (object == self) {
        return YES;
    }
    else if ([self class] != [object class]) {
        return NO;
    }
    else {
        BOOL isEqual = YES;
        isEqual &= self.count == object.count;
        isEqual &= self.timeUnit == object.timeUnit;
        return isEqual;
    }
}

@end
