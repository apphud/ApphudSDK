
#import <Foundation/Foundation.h>

@interface AMAVirtualMachineError : NSObject

@property (nonatomic, copy, readonly) NSString *className;
@property (nonatomic, copy, readonly) NSString *message;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)initWithClassName:(NSString *)className
                          message:(NSString *)message;

@end
