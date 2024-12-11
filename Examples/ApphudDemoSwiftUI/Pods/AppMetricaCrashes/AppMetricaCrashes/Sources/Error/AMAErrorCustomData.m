
#import "AMAErrorCustomData.h"

@implementation AMAErrorCustomData

- (instancetype)initWithIdentifier:(NSString *)identifier
                           message:(NSString *)message
                         className:(NSString *)className
{
    self = [super init];
    if (self != nil) {
        _identifier = [identifier copy];
        _message = [message copy];
        _className = [className copy];
    }
    return self;
}

@end
