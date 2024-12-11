
#import <Foundation/Foundation.h>

NS_SWIFT_NAME(AllocationsTracking)
@protocol AMAAllocationsTracking <NSObject>

- (void *)allocateSize:(size_t)size;

@end
