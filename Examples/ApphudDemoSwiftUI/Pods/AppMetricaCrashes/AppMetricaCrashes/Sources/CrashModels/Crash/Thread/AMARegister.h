
#import <Foundation/Foundation.h>

@interface AMARegister : NSObject

@property (nonatomic, copy, readonly) NSString *name;
@property (nonatomic, assign, readonly) uint64_t value;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithName:(NSString *)name value:(uint64_t)value;

@end
