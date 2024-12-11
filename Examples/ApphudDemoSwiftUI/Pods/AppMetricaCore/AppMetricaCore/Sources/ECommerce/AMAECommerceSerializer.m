
#import "AMACore.h"
#import "AMAECommerceSerializer.h"
#import "AMAECommerce+Internal.h"
#import "AMABinaryEventValue.h"
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>

static NSUInteger const kAMAMaxCartItemsBytesInOrder = 200 * 1024;

@implementation AMAECommerceSerializer

#pragma mark - Public -

- (NSArray<AMAECommerceSerializationResult *> *)serializeECommerce:(AMAECommerce *)value
{
    if (value.eventType == AMAECommerceEventTypePurchase) {
        return [self serializeECommerceOrderEvent:value.order
                                         withType:AMAECommerceEventTypePurchase
                              totalBytesTruncated:value.bytesTruncated];
    }
    else if (value.eventType  == AMAECommerceEventTypeBeginCheckout) {
        return [self serializeECommerceOrderEvent:value.order
                                         withType:AMAECommerceEventTypeBeginCheckout
                              totalBytesTruncated:value.bytesTruncated];
    }

    AMAECommerceSerializationResult *__block result = nil;
    [AMAAllocationsTrackerProvider track:^(id<AMAAllocationsTracking> tracker) {
        Ama__ECommerceEvent message = AMA__ECOMMERCE_EVENT__INIT;
        message.has_type = true;
        message.type = [self eventTypeForType:value.eventType];

        switch (value.eventType) {
            case AMAECommerceEventTypeScreen: {
                message.shown_screen_info = [tracker allocateSize:sizeof(Ama__ECommerceEvent__ShownScreenInfo)];
                ama__ecommerce_event__shown_screen_info__init(message.shown_screen_info);
                message.shown_screen_info->screen = [self serializeScreen:value.screen tracker:tracker];
                break;
            }
            case AMAECommerceEventTypeProductCard: {
                message.shown_product_card_info =
                    [tracker allocateSize:sizeof(Ama__ECommerceEvent__ShownProductCardInfo)];
                ama__ecommerce_event__shown_product_card_info__init(message.shown_product_card_info);
                message.shown_product_card_info->product = [self serializeProduct:value.product tracker:tracker];
                message.shown_product_card_info->screen = [self serializeScreen:value.screen tracker:tracker];
                break;
            }
            case AMAECommerceEventTypeProductDetails: {
                message.shown_product_details_info =
                    [tracker allocateSize:sizeof(Ama__ECommerceEvent__ShownProductDetailsInfo)];
                ama__ecommerce_event__shown_product_details_info__init(message.shown_product_details_info);
                message.shown_product_details_info->product = [self serializeProduct:value.product tracker:tracker];
                message.shown_product_details_info->referrer = [self serializeReferrer:value.referrer tracker:tracker];
                break;
            }

            case AMAECommerceEventTypeAddToCart:
            case AMAECommerceEventTypeRemoveFromCart: {
                message.cart_action_info = [tracker allocateSize:sizeof(Ama__ECommerceEvent__CartActionInfo)];
                ama__ecommerce_event__cart_action_info__init(message.cart_action_info);
                message.cart_action_info->item = [self serializeCartItem:value.cartItem tracker:tracker];
                break;
            }

            case AMAECommerceEventTypeBeginCheckout:
                AMALogAssert(@"BeginCheckout has different logic.");
                break;
            case AMAECommerceEventTypePurchase:
                AMALogAssert(@"Purchase has different logic.");
                break;
        }

        result = [[AMAECommerceSerializationResult alloc] initWithData:[self dataForMessage:&message]
                                                        bytesTruncated:value.bytesTruncated];
    }];

    return result != nil ? @[ result ] : @[];
}

- (Ama__ECommerceEvent *)deserializeECommerceEvent:(id)value allocator:(AMAProtobufAllocator *)allocator
{
    if ([value isKindOfClass:AMABinaryEventValue.class] == NO) {
        return NULL;
    }
    NSData *data = ((AMABinaryEventValue *) value).data;
    return ama__ecommerce_event__unpack(allocator.protobufCAllocator, data.length, data.bytes);
}

#pragma mark - Private -

- (NSArray<AMAECommerceSerializationResult *> *)serializeECommerceOrderEvent:(AMAECommerceOrder *)order
                                                                    withType:(AMAECommerceEventType)type
                                                         totalBytesTruncated:(NSUInteger)totalBytesTruncated
{
    NSMutableArray<AMAECommerceSerializationResult *> *__block result = [NSMutableArray array];
    [AMAAllocationsTrackerProvider track:^(id<AMAAllocationsTracking> tracker) {
        Ama__ECommerceEvent *message = [tracker allocateSize:sizeof(Ama__ECommerceEvent)];
        ama__ecommerce_event__init(message);
        Ama__ECommerceEvent__Order *orderMessage = [self fillOrderEventMessage:message order:order type:type tracker:tracker];

        if (orderMessage->n_items == 0) {
            NSData *data = [self dataForMessage:message];
            if (data != nil) {
                [result addObject:[[AMAECommerceSerializationResult alloc] initWithData:data
                                                                         bytesTruncated:totalBytesTruncated]];
            }
            return;
        }

        NSUInteger cartItemBytesTruncated = 0;
        for (AMAECommerceCartItem *cartItem in order.cartItems) {
            cartItemBytesTruncated += cartItem.bytesTruncated;
        }

        [self addCartItems:order.cartItems
              eventMessage:message
        itemBytesTruncated:cartItemBytesTruncated
       totalBytesTruncated:totalBytesTruncated
                    result:result
                   tracker:tracker];
    }];
    return [result copy];
}

- (Ama__ECommerceEvent__Order *)fillOrderEventMessage:(Ama__ECommerceEvent *)message
                                                order:(AMAECommerceOrder *)order
                                                 type:(AMAECommerceEventType)type
                                              tracker:(id<AMAAllocationsTracking>)tracker
{
    message->has_type = true;
    message->type = [self eventTypeForType:type];

    Ama__ECommerceEvent__Order *orderMessage = [tracker allocateSize:sizeof(Ama__ECommerceEvent__Order)];
    ama__ecommerce_event__order__init(orderMessage);

    message->order_info = [tracker allocateSize:sizeof(Ama__ECommerceEvent__OrderInfo)];
    ama__ecommerce_event__order_info__init(message->order_info);
    message->order_info->order = orderMessage;

    orderMessage->has_uuid = [AMAProtobufUtilities fillBinaryData:&orderMessage->uuid
                                                      withString:[[[NSUUID UUID] UUIDString] lowercaseString]
                                                         tracker:tracker];
    orderMessage->has_order_id = [AMAProtobufUtilities fillBinaryData:&orderMessage->order_id
                                                           withString:order.identifier
                                                              tracker:tracker];
    orderMessage->payload = [self serializePayload:order.internalPayload tracker:tracker];
    orderMessage->has_total_items_count = true;
    orderMessage->total_items_count = (uint32_t)order.cartItems.count;

    orderMessage->n_items = order.cartItems.count;
    orderMessage->items = [tracker allocateSize:sizeof(Ama__ECommerceEvent__OrderCartItem *) * orderMessage->n_items];
    return orderMessage;
}

- (void)addCartItems:(NSArray<AMAECommerceCartItem *> *)cartItems
        eventMessage:(Ama__ECommerceEvent *)eventMessage
  itemBytesTruncated:(NSUInteger)cartItemBytesTruncated
 totalBytesTruncated:(NSUInteger)totalBytesTruncated
              result:(NSMutableArray<AMAECommerceSerializationResult *> *)result
             tracker:(id<AMAAllocationsTracking>)tracker
{
    Ama__ECommerceEvent__Order *orderMessage = eventMessage->order_info->order;
    NSUInteger __block itemIndex = 0;
    NSUInteger __block totalSize = 0;
    NSUInteger __block bytesTruncated = totalBytesTruncated - cartItemBytesTruncated;

    [cartItems enumerateObjectsUsingBlock:^(AMAECommerceCartItem *cartItem, NSUInteger globalIndex, BOOL *stop) {
        Ama__ECommerceEvent__OrderCartItem *orderCartItem =
            [tracker allocateSize:sizeof(Ama__ECommerceEvent__OrderCartItem)];
        ama__ecommerce_event__order_cart_item__init(orderCartItem);
        orderCartItem->has_number_in_cart = true;
        orderCartItem->number_in_cart = (uint32_t)globalIndex;
        orderCartItem->item = [self serializeCartItem:cartItem tracker:tracker];

        NSUInteger cartItemSize =
            (NSUInteger)protobuf_c_message_get_packed_size((const ProtobufCMessage *)(orderCartItem));
        if (totalSize + cartItemSize > kAMAMaxCartItemsBytesInOrder) {
            orderMessage->n_items = itemIndex;
            NSData *data = [self dataForMessage:eventMessage];
            if (data != nil) {
                [result addObject:[[AMAECommerceSerializationResult alloc] initWithData:data
                                                                         bytesTruncated:bytesTruncated]];
            }

            itemIndex = 0;
            totalSize = 0;
            bytesTruncated = totalBytesTruncated - cartItemBytesTruncated;
        }

        totalSize += cartItemSize;
        bytesTruncated += cartItem.bytesTruncated;
        orderMessage->items[itemIndex] = orderCartItem;
        itemIndex += 1;
    }];

    orderMessage->n_items = itemIndex;
    NSData *data = [self dataForMessage:eventMessage];
    if (data != nil) {
        [result addObject:[[AMAECommerceSerializationResult alloc] initWithData:data
                                                                 bytesTruncated:bytesTruncated]];
    }
}

- (NSData *)dataForMessage:(Ama__ECommerceEvent *)message
{
    size_t dataSize = ama__ecommerce_event__get_packed_size(message);
    uint8_t *bytes = malloc(dataSize);
    ama__ecommerce_event__pack(message, bytes);
    return [NSData dataWithBytesNoCopy:bytes length:dataSize];
}

- (Ama__ECommerceEvent__ECommerceEventType)eventTypeForType:(AMAECommerceEventType)eventType
{
    switch (eventType) {
        case AMAECommerceEventTypeScreen:
            return AMA__ECOMMERCE_EVENT__ECOMMERCE_EVENT_TYPE__ECOMMERCE_EVENT_TYPE_SHOW_SCREEN;
        case AMAECommerceEventTypeProductCard:
            return AMA__ECOMMERCE_EVENT__ECOMMERCE_EVENT_TYPE__ECOMMERCE_EVENT_TYPE_SHOW_PRODUCT_CARD;
        case AMAECommerceEventTypeProductDetails:
            return AMA__ECOMMERCE_EVENT__ECOMMERCE_EVENT_TYPE__ECOMMERCE_EVENT_TYPE_SHOW_PRODUCT_DETAILS;
        case AMAECommerceEventTypeAddToCart:
            return AMA__ECOMMERCE_EVENT__ECOMMERCE_EVENT_TYPE__ECOMMERCE_EVENT_TYPE_ADD_TO_CART;
        case AMAECommerceEventTypeRemoveFromCart:
            return AMA__ECOMMERCE_EVENT__ECOMMERCE_EVENT_TYPE__ECOMMERCE_EVENT_TYPE_REMOVE_FROM_CART;
        case AMAECommerceEventTypeBeginCheckout:
            return AMA__ECOMMERCE_EVENT__ECOMMERCE_EVENT_TYPE__ECOMMERCE_EVENT_TYPE_BEGIN_CHECKOUT;
        case AMAECommerceEventTypePurchase:
            return AMA__ECOMMERCE_EVENT__ECOMMERCE_EVENT_TYPE__ECOMMERCE_EVENT_TYPE_PURCHASE;
        default:
            return AMA__ECOMMERCE_EVENT__ECOMMERCE_EVENT_TYPE__ECOMMERCE_EVENT_TYPE_UNDEFINED;
    }
}

- (Ama__ECommerceEvent__Screen *)serializeScreen:(AMAECommerceScreen *)screen
                                         tracker:(id<AMAAllocationsTracking>)tracker
{
    if (screen == nil) {
        return NULL;
    }

    Ama__ECommerceEvent__Screen *result = [tracker allocateSize:sizeof(Ama__ECommerceEvent__Screen)];
    ama__ecommerce_event__screen__init(result);

    result->has_name = [AMAProtobufUtilities fillBinaryData:&result->name
                                                 withString:screen.name
                                                    tracker:tracker];
    result->has_search_query = [AMAProtobufUtilities fillBinaryData:&result->search_query
                                                         withString:screen.searchQuery
                                                            tracker:tracker];
    result->category = [self serializeCategory:screen.categoryComponents tracker:tracker];
    result->payload = [self serializePayload:screen.internalPayload tracker:tracker];
    return result;
}

- (Ama__ECommerceEvent__Product *)serializeProduct:(AMAECommerceProduct *)product
                                           tracker:(id<AMAAllocationsTracking>)tracker
{
    if (product == nil) {
        return nil;
    }

    Ama__ECommerceEvent__Product *result = [tracker allocateSize:sizeof(Ama__ECommerceEvent__Product)];
    ama__ecommerce_event__product__init(result);

    result->has_sku = [AMAProtobufUtilities fillBinaryData:&result->sku withString:product.sku tracker:tracker];
    result->has_name = [AMAProtobufUtilities fillBinaryData:&result->name withString:product.name tracker:tracker];
    result->category = [self serializeCategory:product.categoryComponents tracker:tracker];
    result->payload = [self serializePayload:product.internalPayload tracker:tracker];
    result->actual_price = [self serializePrice:product.actualPrice tracker:tracker];
    result->original_price = [self serializePrice:product.originalPrice tracker:tracker];

    result->n_promo_codes = product.promoCodes.count;
    if (result->n_promo_codes != 0) {
        result->promo_codes = [tracker allocateSize:sizeof(Ama__ECommerceEvent__PromoCode *) * result->n_promo_codes];
        [product.promoCodes enumerateObjectsUsingBlock:^(NSString *promoCode, NSUInteger idx, BOOL *stop) {
            result->promo_codes[idx] = [self serializePromoCode:promoCode tracker:tracker];
        }];
    }

    return result;
}

- (Ama__ECommerceEvent__Referrer *)serializeReferrer:(AMAECommerceReferrer *)referrer
                                             tracker:(id<AMAAllocationsTracking>)tracker
{
    if (referrer == nil) {
        return NULL;
    }

    Ama__ECommerceEvent__Referrer *result = [tracker allocateSize:sizeof(Ama__ECommerceEvent__Referrer)];
    ama__ecommerce_event__referrer__init(result);

    result->has_type = [AMAProtobufUtilities fillBinaryData:&result->type withString:referrer.type tracker:tracker];
    result->has_id = [AMAProtobufUtilities fillBinaryData:&result->id withString:referrer.identifier tracker:tracker];
    result->screen = [self serializeScreen:referrer.screen tracker:tracker];

    return result;
}

- (Ama__ECommerceEvent__CartItem *)serializeCartItem:(AMAECommerceCartItem *)cartItem
                                             tracker:(id<AMAAllocationsTracking>)tracker
{
    if (cartItem == nil) {
        return NULL;
    }

    Ama__ECommerceEvent__CartItem *result = [tracker allocateSize:sizeof(Ama__ECommerceEvent__CartItem)];
    ama__ecommerce_event__cart_item__init(result);

    result->product = [self serializeProduct:cartItem.product tracker:tracker];
    result->referrer = [self serializeReferrer:cartItem.referrer tracker:tracker];
    result->quantity = [self serializeDecimal:cartItem.quantity tracker:tracker];
    result->revenue = [self serializePrice:cartItem.revenue tracker:tracker];

    return result;
}

- (Ama__ECommerceEvent__Category *)serializeCategory:(NSArray *)categoryComponents
                                             tracker:(id<AMAAllocationsTracking>)tracker
{
    if (categoryComponents == nil) {
        return NULL;
    }

    Ama__ECommerceEvent__Category *result = [tracker allocateSize:sizeof(Ama__ECommerceEvent__Category)];
    ama__ecommerce_event__category__init(result);

    result->n_path = categoryComponents.count;
    if (result->n_path != 0) {
        result->path = [tracker allocateSize:sizeof(ProtobufCBinaryData) * result->n_path];
        [categoryComponents enumerateObjectsUsingBlock:^(NSString *item, NSUInteger idx, BOOL *stop) {
            [AMAProtobufUtilities fillBinaryData:&(result->path[idx]) withString:item tracker:tracker];
        }];
    }

    return result;
}

- (Ama__ECommerceEvent__PromoCode *)serializePromoCode:(NSString *)promoCode
                                               tracker:(id<AMAAllocationsTracking>)tracker
{
    if (promoCode == nil) {
        return NULL;
    }

    Ama__ECommerceEvent__PromoCode *result = [tracker allocateSize:sizeof(Ama__ECommerceEvent__PromoCode)];
    ama__ecommerce_event__promo_code__init(result);

    result->has_code = [AMAProtobufUtilities fillBinaryData:&result->code withString:promoCode tracker:tracker];

    return result;
}

- (Ama__ECommerceEvent__Payload *)serializePayload:(AMAECommercePayload *)payload
                                           tracker:(id<AMAAllocationsTracking>)tracker
{
    if (payload == nil) {
        return NULL;
    }

    Ama__ECommerceEvent__Payload *result = [tracker allocateSize:sizeof(Ama__ECommerceEvent__Payload)];
    ama__ecommerce_event__payload__init(result);

    result->has_truncated_pairs_count = true;
    result->truncated_pairs_count = (uint32_t)payload.truncatedPairsCount;

    result->n_pairs = payload.pairs.count;
    if (result->n_pairs != 0) {
        result->pairs = [tracker allocateSize:sizeof(Ama__ECommerceEvent__Payload__Pair *) * result->n_pairs];
        NSUInteger index = 0;
        for (NSString *key in payload.pairs) {
            NSString *value = payload.pairs[key];
            Ama__ECommerceEvent__Payload__Pair *pair = [tracker allocateSize:sizeof(Ama__ECommerceEvent__Payload__Pair)];
            ama__ecommerce_event__payload__pair__init(pair);

            pair->has_key = [AMAProtobufUtilities fillBinaryData:&pair->key withString:key tracker:tracker];
            pair->has_value = [AMAProtobufUtilities fillBinaryData:&pair->value withString:value tracker:tracker];

            result->pairs[index] = pair;
            index += 1;
        }
    }

    return result;
}

- (Ama__ECommerceEvent__Price *)serializePrice:(AMAECommercePrice *)price
                                       tracker:(id<AMAAllocationsTracking>)tracker
{
    if (price == nil) {
        return NULL;
    }

    Ama__ECommerceEvent__Price *result = [tracker allocateSize:sizeof(Ama__ECommerceEvent__Price)];
    ama__ecommerce_event__price__init(result);

    result->fiat = [self serializeAmount:price.fiat tracker:tracker];

    result->n_internal_components = price.internalComponents.count;
    if (result->n_internal_components != 0) {
        result->internal_components = [tracker allocateSize:sizeof(Ama__ECommerceEvent__Amount *)
                                                            * result->n_internal_components];
        [price.internalComponents enumerateObjectsUsingBlock:^(AMAECommerceAmount *component, NSUInteger idx, BOOL *stop) {
            result->internal_components[idx] = [self serializeAmount:component tracker:tracker];
        }];
    }

    return result;
}

- (Ama__ECommerceEvent__Amount *)serializeAmount:(AMAECommerceAmount *)amount
                                         tracker:(id<AMAAllocationsTracking>)tracker
{
    if (amount == nil) {
        return NULL;
    }

    Ama__ECommerceEvent__Amount *result = [tracker allocateSize:sizeof(Ama__ECommerceEvent__Amount)];
    ama__ecommerce_event__amount__init(result);

    result->has_unit_type = [AMAProtobufUtilities fillBinaryData:&result->unit_type
                                                      withString:amount.unit
                                                         tracker:tracker];
    result->value = [self serializeDecimal:amount.value tracker:tracker];

    return result;
}

- (Ama__ECommerceEvent__Decimal *)serializeDecimal:(NSDecimalNumber *)decimal
                                           tracker:(id<AMAAllocationsTracking>)tracker
{
    if (decimal == nil) {
        return NULL;
    }

    Ama__ECommerceEvent__Decimal *result = [tracker allocateSize:sizeof(Ama__ECommerceEvent__Decimal)];
    ama__ecommerce_event__decimal__init(result);

    BOOL filled = [AMADecimalUtils fillMantissa:&result->mantissa exponent:&result->exponent withDecimal:decimal];
    result->has_exponent = filled;
    result->has_mantissa = filled;

    return result;
}

@end
