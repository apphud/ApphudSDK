
#import <Foundation/Foundation.h>

@interface AMAMemory : NSObject

@property (nonatomic, assign, readonly) uint64_t size;
@property (nonatomic, assign, readonly) uint64_t usable;
@property (nonatomic, assign, readonly) uint64_t free;

- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithSize:(uint64_t)size usable:(uint64_t)usable free:(uint64_t)free;

@end
