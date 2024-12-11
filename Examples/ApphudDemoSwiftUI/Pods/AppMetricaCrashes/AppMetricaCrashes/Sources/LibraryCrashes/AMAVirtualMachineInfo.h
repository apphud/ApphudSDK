
#import <Foundation/Foundation.h>

@interface AMAVirtualMachineInfo : NSObject

@property (nonatomic, copy, readonly) NSString *platform;
@property (nonatomic, copy, readonly) NSString *virtualMachineVersion;
@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *environment;

- (instancetype)initWithPlatform:(NSString *)platform
                         version:(NSString *)version
                     environment:(NSDictionary<NSString *, NSString *> *)environment;

@end
