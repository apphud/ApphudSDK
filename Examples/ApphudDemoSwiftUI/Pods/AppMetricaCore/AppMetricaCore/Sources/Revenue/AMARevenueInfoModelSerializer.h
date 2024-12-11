
#import <Foundation/Foundation.h>
#import "Revenue.pb-c.h"

@class AMARevenueInfoModel;
@class AMAProtobufAllocator;

@interface AMARevenueInfoModelSerializer : NSObject

- (NSData *)dataWithRevenueInfoModel:(AMARevenueInfoModel *)model;
- (Ama__Revenue *)deserializeRevenue:(id)value allocator:(AMAProtobufAllocator *)allocator;

@end
