
#import "AMAInfo.h"
#import "AMAVirtualMachineInfo.h"

@implementation AMAInfo

- (instancetype)initWithVersion:(NSString *)version
                     identifier:(NSString *)identifier
                      timestamp:(NSDate *)timestamp
             virtualMachineInfo:(AMAVirtualMachineInfo *)virtualMachineInfo
{
    self = [super init];
    if (self != nil) {
        _version = [version copy];
        _identifier = [identifier copy];
        _timestamp = timestamp;
        _virtualMachineInfo = virtualMachineInfo;
    }

    return self;
}

@end
