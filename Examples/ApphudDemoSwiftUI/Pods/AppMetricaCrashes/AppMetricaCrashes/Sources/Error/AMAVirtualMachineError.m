
#import "AMAVirtualMachineError.h"

@implementation AMAVirtualMachineError

- (instancetype)initWithClassName:(NSString *)className message:(NSString *)message
{
    self = [super init];
    if (self != nil) {
        _className = [className copy];
        _message = [message copy];
    }
    return self;
}

@end
