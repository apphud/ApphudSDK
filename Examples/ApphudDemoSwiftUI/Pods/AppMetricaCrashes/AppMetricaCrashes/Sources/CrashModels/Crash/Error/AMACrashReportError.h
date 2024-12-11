
#import <Foundation/Foundation.h>

@class AMAMach;
@class AMASignal;
@class AMANSException;
@class AMACppException;
@class AMANonFatal;
@class AMAVirtualMachineCrash;

typedef NS_ENUM(NSInteger, AMACrashType) {
    AMACrashTypeMachException,
    AMACrashTypeSignal,
    AMACrashTypeCppException,
    AMACrashTypeNsException,
    AMACrashTypeMainThreadDeadlock,
    AMACrashTypeUserReported,
    AMACrashTypeNonFatal,
    AMACrashTypeVirtualMachineCrash,
    AMACrashTypeVirtualMachineError,
    AMACrashTypeVirtualMachineCustomError,
};

@interface AMACrashReportError : NSObject

@property (nonatomic, assign, readonly) uint64_t address;
@property (nonatomic, copy, readonly) NSString *reason;
@property (nonatomic, assign, readonly) AMACrashType type;
@property (nonatomic, strong, readonly) AMAMach *mach;
@property (nonatomic, strong, readonly) AMASignal *signal;
@property (nonatomic, strong, readonly) AMANSException *nsException;
@property (nonatomic, strong, readonly) AMACppException *cppException;
@property (nonatomic, copy, readonly) NSArray<AMANonFatal *> *nonFatalsChain;
@property (nonatomic, strong, readonly) AMAVirtualMachineCrash *virtualMachineCrash;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithAddress:(uint64_t)address
                         reason:(NSString *)reason
                           type:(AMACrashType)type
                           mach:(AMAMach *)mach
                         signal:(AMASignal *)signal
                    nsexception:(AMANSException *)nsException
                   cppException:(AMACppException *)cppException
                 nonFatalsChain:(NSArray<AMANonFatal *> *)nonFatalsChain
            virtualMachineCrash:(AMAVirtualMachineCrash *)virtualMachineCrash;


@end
