
#import <Foundation/Foundation.h>
#import "AMAECommerceSerializationResult.h"
#import "Ecommerce.pb-c.h"

@class AMAECommerce;
@class AMAProtobufAllocator;

@interface AMAECommerceSerializer : NSObject

- (NSArray<AMAECommerceSerializationResult *> *)serializeECommerce:(AMAECommerce *)value;
- (Ama__ECommerceEvent *)deserializeECommerceEvent:(id)value allocator:(AMAProtobufAllocator *)allocator;

@end
