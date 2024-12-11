
#import <Foundation/Foundation.h>

@class AMAVirtualMachineInfo;

@interface AMAInfo : NSObject

@property (nonatomic, copy, readonly) NSString *version;
@property (nonatomic, copy, readonly) NSString *identifier;
@property (nonatomic, strong, readonly) NSDate *timestamp;
@property (nonatomic, strong, readonly) AMAVirtualMachineInfo *virtualMachineInfo;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithVersion:(NSString *)version
                     identifier:(NSString *)identifier
                      timestamp:(NSDate *)timestamp
             virtualMachineInfo:(AMAVirtualMachineInfo *)virtualMachineInfo;

@end
