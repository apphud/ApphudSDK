
#import "AMALightECommerceEvent.h"

@implementation AMALightECommerceEvent

- (instancetype)initWithType:(AMAECommerceEventType)type
                     amounts:(NSArray<AMAECommerceAmount *> *)amounts
                     isFirst:(BOOL)isFirst
{
    self = [super init];
    if (self != nil) {
        _type = type;
        _amounts = [amounts copy];
        _isFirst = isFirst;
    }
    return self;
}

@end
