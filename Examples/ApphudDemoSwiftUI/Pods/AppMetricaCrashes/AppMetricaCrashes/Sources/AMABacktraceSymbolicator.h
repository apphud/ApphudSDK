
#import <Foundation/Foundation.h>
#import <dlfcn.h>

@class AMABacktrace;
@class AMABinaryImage;

typedef bool AMADLAddrFunction(const uintptr_t address, Dl_info* const info);

@interface AMABacktraceSymbolicator : NSObject

- (instancetype)initWithDLAddrFunction:(AMADLAddrFunction *)dlAddrFunction;

- (AMABacktrace *)backtraceForInstructionAddresses:(NSArray<NSNumber *> *)addresses
                                      binaryImages:(NSSet<AMABinaryImage *> **)binaryImages;

@end
