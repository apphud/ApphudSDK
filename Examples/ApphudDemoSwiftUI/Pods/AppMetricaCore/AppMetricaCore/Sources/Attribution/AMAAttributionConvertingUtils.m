
#import "AMACore.h"
#import "AMAAttributionConvertingUtils.h"
#import "AMAAttributionKeys.h"

NSString *const kAMAAttributionConvertingErrorDomain = @"io.appmetrica.AMAAttributionConverting";

@implementation AMAAttributionConvertingUtils

+ (NSString *)stringForECommerceType:(AMAECommerceEventType)type
{
    switch (type) {
        case AMAECommerceEventTypeRemoveFromCart: return AMAAttributionKeyRemoveCartItem;
        case AMAECommerceEventTypeProductDetails: return AMAAttributionKeyShowProductDetails;
        case AMAECommerceEventTypeProductCard: return AMAAttributionKeyShowProductCard;
        case AMAECommerceEventTypeAddToCart: return AMAAttributionKeyAddCartItem;
        case AMAECommerceEventTypeBeginCheckout: return AMAAttributionKeyBeginCheckout;
        case AMAECommerceEventTypePurchase: return AMAAttributionKeyPurchase;
        case AMAECommerceEventTypeScreen: return AMAAttributionKeyShowScreen;
        default: return @"";
    }
}

+ (AMAECommerceEventType)eCommerceTypeForString:(NSString *)type error:(NSError **)error
{
    if ([AMAAttributionKeyRemoveCartItem isEqualToString:type]) {
        return AMAECommerceEventTypeRemoveFromCart;
    }
    else if ([AMAAttributionKeyShowProductDetails isEqualToString:type]) {
        return AMAECommerceEventTypeProductDetails;
    }
    else if ([AMAAttributionKeyShowProductCard isEqualToString:type]) {
        return AMAECommerceEventTypeProductCard;
    }
    else if ([AMAAttributionKeyAddCartItem isEqualToString:type]) {
        return AMAECommerceEventTypeAddToCart;
    }
    else if ([AMAAttributionKeyBeginCheckout isEqualToString:type]) {
        return AMAECommerceEventTypeBeginCheckout;
    }
    else if ([AMAAttributionKeyPurchase isEqualToString:type]) {
        return AMAECommerceEventTypePurchase;
    }
    else if ([AMAAttributionKeyShowScreen isEqualToString:type]) {
        return AMAECommerceEventTypeScreen;
    } else {
        NSError *internalError = [NSError errorWithDomain:kAMAAttributionConvertingErrorDomain
                                                     code:AMAAttributionConvertingErrorUnknownInput
                                                 userInfo:@{ @"input" : type ?: @"nil" }];
        [AMAErrorUtilities fillError:error withError:internalError];
        AMALogWarn(@"Cannot convert %@ to e-commerce event type", type);
        return AMAECommerceEventTypeScreen;
    }
}

+ (AMAAttributionModelType)modelTypeForString:(NSString *)type
{
    if ([AMAAttributionKeyModelConversion isEqualToString:type]) {
        return AMAAttributionModelTypeConversion;
    }
    else if ([AMAAttributionKeyModelRevenue isEqualToString:type]) {
        return AMAAttributionModelTypeRevenue;
    }
    else if ([AMAAttributionKeyModelEngagement isEqualToString:type]) {
        return AMAAttributionModelTypeEngagement;
    }
    else {
        return AMAAttributionModelTypeUnknown;
    }
}

+ (AMAEventType)eventTypeForString:(NSString *)type error:(NSError **)error
{
    if ([AMAAttributionKeyClient isEqualToString:type]) {
        return AMAEventTypeClient;
    }
    else if ([AMAAttributionKeyRevenue isEqualToString:type]) {
        return AMAEventTypeRevenue;
    }
    else if ([AMAAttributionKeyECom isEqualToString:type]) {
        return AMAEventTypeECommerce;
    }
    else {
        NSError *internalError = [NSError errorWithDomain:kAMAAttributionConvertingErrorDomain
                                                     code:AMAAttributionConvertingErrorUnknownInput
                                                 userInfo:@{ @"input" : type ?: @"nil" }];
        [AMAErrorUtilities fillError:error withError:internalError];
        AMALogWarn(@"Cannot convert %@ to event type", type);
        return AMAEventTypeClient;
    }
}

+ (AMARevenueSource)revenueSourceForString:(NSString *)source error:(NSError **)error
{
    if ([AMAAttributionKeyAPI isEqualToString:source]) {
        return AMARevenueSourceAPI;
    }
    else if ([AMAAttributionKeyAuto isEqualToString:source]) {
        return AMARevenueSourceAuto;
    }
    else {
        NSError *internalError = [NSError errorWithDomain:kAMAAttributionConvertingErrorDomain
                                                     code:AMAAttributionConvertingErrorUnknownInput
                                                 userInfo:@{ @"input" : source ?: @"nil" }];
        [AMAErrorUtilities fillError:error withError:internalError];
        AMALogWarn(@"Cannot convert %@ to revenue source", source);
        return AMARevenueSourceAPI;
    }
}

@end
