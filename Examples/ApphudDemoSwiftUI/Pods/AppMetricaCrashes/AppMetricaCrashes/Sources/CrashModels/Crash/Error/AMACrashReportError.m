
#import "AMAVirtualMachineCrash.h"
#import "AMACrashReportError.h"

@implementation AMACrashReportError

- (instancetype)initWithAddress:(uint64_t)address
                         reason:(NSString *)reason
                           type:(AMACrashType)type
                           mach:(AMAMach *)mach
                         signal:(AMASignal *)signal
                    nsexception:(AMANSException *)nsException
                   cppException:(AMACppException *)cppException
                 nonFatalsChain:(NSArray<AMANonFatal *> *)nonFatalsChain
            virtualMachineCrash:(AMAVirtualMachineCrash *)virtualMachineCrash
{
    self = [super init];
    if (self != nil) {
        _address = address;
        _reason = [reason copy];
        _type = type;
        _mach = mach;
        _signal = signal;
        _nsException = nsException;
        _cppException = cppException;
        _nonFatalsChain = [nonFatalsChain copy];
        _virtualMachineCrash = virtualMachineCrash;
    }

    return self;
}

@end
