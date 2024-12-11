
#import "AMALightECommerceEventConverter.h"
#import "AMAECommerceUtils.h"
#import "AMALightECommerceEvent.h"
#import "AMAECommerceSerializer.h"
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>

@interface AMALightECommerceEventConverter ()

@property (nonatomic, strong, readonly) AMAECommerceSerializer *serializer;

@end

@implementation AMALightECommerceEventConverter

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _serializer = [[AMAECommerceSerializer alloc] init];
    }
    return self;
}

- (AMALightECommerceEvent *)eventFromModel:(AMAECommerce *)event
{
    NSMutableArray<AMAECommerceAmount *> *amounts = [[NSMutableArray alloc] initWithCapacity:event.order.cartItems.count];
    for (AMAECommerceCartItem *cartItem in event.order.cartItems) {
        if (cartItem.revenue.fiat != nil) {
            [amounts addObject:cartItem.revenue.fiat];
        }
    }
    return [[AMALightECommerceEvent alloc] initWithType:event.eventType
                                                amounts:amounts
                                                isFirst:YES];
}

- (AMALightECommerceEvent *)eventFromSerializedValue:(id)value
{
    NS_VALID_UNTIL_END_OF_SCOPE AMAProtobufAllocator *allocator = [[AMAProtobufAllocator alloc] init];
    Ama__ECommerceEvent *event = [self.serializer deserializeECommerceEvent:value allocator:allocator];
    if (event == NULL) {
        return nil;
    }
    NSError *error = nil;
    AMAECommerceEventType type = [AMAECommerceUtils convertECommerceEventProtoType:event->type error:&error];
    if (error != nil) {
        return nil;
    }
    BOOL isFirst = [AMAECommerceUtils isFirstECommerceEvent:event];
    NSArray<AMAECommerceAmount *> *amounts = [AMAECommerceUtils getECommerceMoneyFromOrder:event->order_info];
    return [[AMALightECommerceEvent alloc] initWithType:type
                                                amounts:amounts
                                                isFirst:isFirst];
}

@end
