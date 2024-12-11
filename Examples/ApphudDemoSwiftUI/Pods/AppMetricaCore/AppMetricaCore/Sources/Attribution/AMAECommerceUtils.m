
#import "AMACore.h"
#import "AMAECommerceUtils.h"
#import "Ecommerce.pb-c.h"
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>

const AMAECommerceEventType kAMADefaultECommerceEventType = AMAECommerceEventTypeScreen;
NSString *const kAMAConvertingErrorDomain = @"io.appmetrica.AMAConverting";

@implementation AMAECommerceUtils

#pragma mark - Public -

+ (AMAECommerceEventType)convertECommerceEventProtoType:(Ama__ECommerceEvent__ECommerceEventType)type error:(NSError **)error
{
    switch (type) {
        case AMA__ECOMMERCE_EVENT__ECOMMERCE_EVENT_TYPE__ECOMMERCE_EVENT_TYPE_PURCHASE: return AMAECommerceEventTypePurchase;
        case AMA__ECOMMERCE_EVENT__ECOMMERCE_EVENT_TYPE__ECOMMERCE_EVENT_TYPE_BEGIN_CHECKOUT: return AMAECommerceEventTypeBeginCheckout;
        case AMA__ECOMMERCE_EVENT__ECOMMERCE_EVENT_TYPE__ECOMMERCE_EVENT_TYPE_ADD_TO_CART: return AMAECommerceEventTypeAddToCart;
        case AMA__ECOMMERCE_EVENT__ECOMMERCE_EVENT_TYPE__ECOMMERCE_EVENT_TYPE_REMOVE_FROM_CART: return AMAECommerceEventTypeRemoveFromCart;
        case AMA__ECOMMERCE_EVENT__ECOMMERCE_EVENT_TYPE__ECOMMERCE_EVENT_TYPE_SHOW_PRODUCT_CARD: return AMAECommerceEventTypeProductCard;
        case AMA__ECOMMERCE_EVENT__ECOMMERCE_EVENT_TYPE__ECOMMERCE_EVENT_TYPE_SHOW_SCREEN: return AMAECommerceEventTypeScreen;
        case AMA__ECOMMERCE_EVENT__ECOMMERCE_EVENT_TYPE__ECOMMERCE_EVENT_TYPE_SHOW_PRODUCT_DETAILS: return AMAECommerceEventTypeProductDetails;
        default: {
            *error = [NSError errorWithDomain:kAMAConvertingErrorDomain
                                         code:AMAInvalidData
                                     userInfo:@{}];
            AMALogWarn(@"Cannot convert %d to e-commerce event type", type);
            return kAMADefaultECommerceEventType;
        }
    }
}

+ (BOOL)isFirstECommerceEvent:(Ama__ECommerceEvent *)eCommerceData
{
    Ama__ECommerceEvent__OrderInfo *orderInfo = eCommerceData->order_info;
    if (orderInfo != NULL) {
        Ama__ECommerceEvent__Order *order = orderInfo->order;
        if (order != NULL) {
            if (order->items != NULL && order->n_items > 0) {
                Ama__ECommerceEvent__OrderCartItem *orderCartItem = order->items[0];
                if (orderCartItem != NULL) {
                    return orderCartItem->number_in_cart == 0;
                }
            }
        }
    }
    return YES;
}

+ (NSArray<AMAECommerceAmount *>*)getECommerceMoneyFromOrder:(Ama__ECommerceEvent__OrderInfo *)orderInfo
{
    NSMutableArray<AMAECommerceAmount *> *cartItems = [[NSMutableArray alloc] init];
    if (orderInfo != NULL) {
        Ama__ECommerceEvent__Order *order = orderInfo->order;
        if (order != NULL) {
            if (order->items != NULL) {
                for (size_t i = 0; i < order->n_items; i++) {
                    Ama__ECommerceEvent__OrderCartItem *orderCartItem = order->items[i];
                    if (orderCartItem != NULL) {
                        Ama__ECommerceEvent__CartItem *item = orderCartItem->item;
                        if (item != NULL) {
                            Ama__ECommerceEvent__Price *price = item->revenue;
                            AMAECommerceAmount *amount = [self extractAmountFromPrice:price];
                            if (amount != nil) {
                                [cartItems addObject:amount];
                            }
                        }
                    }
                }
            }
        }
    }
    return cartItems;
}

#pragma mark - Private -

+ (AMAECommerceAmount *)extractAmountFromPrice:(Ama__ECommerceEvent__Price *)price
{
    if (price != NULL) {
        Ama__ECommerceEvent__Amount *fiat = price->fiat;
        if (fiat != NULL) {
            Ama__ECommerceEvent__Decimal *fiatValue = fiat->value;
            if (fiatValue != NULL) {
                NSDecimalNumber *decimalNumber = [AMADecimalUtils decimalFromMantissa:fiatValue->mantissa
                                                                             exponent:fiatValue->exponent];
                NSString *unit = [AMAProtobufUtilities stringForBinaryData:&fiat->unit_type
                                                                       has:fiat->has_unit_type];
                return [[AMAECommerceAmount alloc] initWithUnit:unit value:decimalNumber];
            }
        }
    }
    return nil;
}

@end
