
#import "AMAVirtualMachineInfo.h"

@implementation AMAVirtualMachineInfo

- (instancetype)initWithPlatform:(NSString *)platform
                         version:(NSString *)version
                     environment:(NSDictionary<NSString *, NSString *> *)environment
{
    self = [super init];
    if (self != nil) {
        _platform = [platform copy];
        _virtualMachineVersion = [version copy];
        _environment = [environment copy];
    }
    return self;
}

@end
