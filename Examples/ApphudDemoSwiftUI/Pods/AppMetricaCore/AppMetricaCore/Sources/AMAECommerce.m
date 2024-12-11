
#import "AMAECommerce+Internal.h"

@implementation AMAECommercePayload

- (instancetype)initWithPairs:(NSDictionary<NSString *,NSString *> *)pairs
          truncatedPairsCount:(NSUInteger)truncatedPairsCount
{
    self = [super init];
    if (self != nil) {
        _pairs = [pairs copy];
        _truncatedPairsCount = truncatedPairsCount;
    }
    return self;
}

@end

@implementation AMAECommerceAmount

- (instancetype)initWithUnit:(NSString *)unit value:(NSDecimalNumber *)value
{
    self = [super init];
    if (self != nil) {
        _unit = [unit copy];
        _value = value;
    }
    return self;
}

@end

@implementation AMAECommercePrice

- (instancetype)initWithFiat:(AMAECommerceAmount *)fiat
{
    return [self initWithFiat:fiat internalComponents:nil];
}

- (instancetype)initWithFiat:(AMAECommerceAmount *)fiat
          internalComponents:(NSArray<AMAECommerceAmount *> *)internalComponents
{
    self = [super init];
    if (self != nil) {
        _fiat = fiat;
        _internalComponents = internalComponents;
    }
    return self;
}

@end

@implementation AMAECommerceScreen

- (instancetype)initWithName:(NSString *)name
{
    return [self initWithName:name categoryComponents:nil searchQuery:nil payload:nil];
}

- (instancetype)initWithCategoryComponents:(NSArray<NSString *> *)categoryComponents
{
    return [self initWithName:nil categoryComponents:categoryComponents searchQuery:nil payload:nil];
}

- (instancetype)initWithSearchQuery:(NSString *)searchQuery
{
    return [self initWithName:nil categoryComponents:nil searchQuery:searchQuery payload:nil];
}

- (instancetype)initWithPayload:(NSDictionary<NSString *, NSString *> *)payload
{
    return [self initWithName:nil categoryComponents:nil searchQuery:nil payload:payload];
}

- (instancetype)initWithName:(NSString *)name
          categoryComponents:(NSArray<NSString *> *)categoryComponents
                 searchQuery:(NSString *)searchQuery
                     payload:(NSDictionary<NSString *, NSString *> *)payload
{
    return [self initWithName:name
           categoryComponents:categoryComponents
                  searchQuery:searchQuery
              internalPayload:[[AMAECommercePayload alloc] initWithPairs:payload truncatedPairsCount:0]];
}

- (instancetype)initWithName:(NSString *)name
          categoryComponents:(NSArray<NSString *> *)categoryComponents
                 searchQuery:(NSString *)searchQuery
             internalPayload:(AMAECommercePayload *)internalPayload
{
    self = [super init];
    if (self != nil) {
        _name = [name copy];
        _categoryComponents = [categoryComponents copy];
        _searchQuery = [searchQuery copy];
        _internalPayload = internalPayload;
    }
    return self;
}

- (NSDictionary<NSString *,NSString *> *)payload
{
    return self.internalPayload.pairs;
}

@end

@implementation AMAECommerceProduct

- (instancetype)initWithSKU:(NSString *)sku
{
    return [self initWithSKU:sku
                        name:nil
          categoryComponents:nil
                     payload:nil
                 actualPrice:nil
               originalPrice:nil
                  promoCodes:nil];
}

- (instancetype)initWithSKU:(NSString *)sku
                       name:(NSString *)name
         categoryComponents:(NSArray<NSString *> *)categoryComponents
                    payload:(NSDictionary<NSString *, NSString *> *)payload
                actualPrice:(AMAECommercePrice *)actualPrice
              originalPrice:(AMAECommercePrice *)originalPrice
                 promoCodes:(NSArray<NSString *> *)promoCodes
{
    return [self initWithSKU:sku
                        name:name
          categoryComponents:categoryComponents
             internalPayload:[[AMAECommercePayload alloc] initWithPairs:payload truncatedPairsCount:0]
                 actualPrice:actualPrice
               originalPrice:originalPrice
                  promoCodes:promoCodes];
}

- (instancetype)initWithSKU:(NSString *)sku
                       name:(NSString *)name
         categoryComponents:(NSArray<NSString *> *)categoryComponents
            internalPayload:(AMAECommercePayload *)internalPayload
                actualPrice:(AMAECommercePrice *)actualPrice
              originalPrice:(AMAECommercePrice *)originalPrice
                 promoCodes:(NSArray<NSString *> *)promoCodes
{
    self = [super init];
    if (self != nil) {
        _sku = [sku copy];
        _name = [name copy];
        _categoryComponents = [categoryComponents copy];
        _internalPayload = internalPayload;
        _actualPrice = actualPrice;
        _originalPrice = originalPrice;
        _promoCodes = [promoCodes copy];
    }
    return self;
}

- (NSDictionary<NSString *,NSString *> *)payload
{
    return self.internalPayload.pairs;
}

@end

@implementation AMAECommerceReferrer

- (instancetype)initWithType:(NSString *)type
                  identifier:(NSString *)identifier
                      screen:(AMAECommerceScreen *)screen
{
    self = [super init];
    if (self != nil) {
        _type = [type copy];
        _identifier = [identifier copy];
        _screen = screen;
    }
    return self;
}

@end

@implementation AMAECommerceCartItem

- (instancetype)initWithProduct:(AMAECommerceProduct *)product
                       quantity:(NSDecimalNumber *)quantity
                        revenue:(AMAECommercePrice *)revenue
                       referrer:(AMAECommerceReferrer *)referrer
{
    return [self initWithProduct:product
                        referrer:referrer
                        quantity:quantity
                         revenue:revenue
                  bytesTruncated:0];
}

- (instancetype)initWithProduct:(AMAECommerceProduct *)product
                       referrer:(AMAECommerceReferrer *)referrer
                       quantity:(NSDecimalNumber *)quantity
                        revenue:(AMAECommercePrice *)revenue
                 bytesTruncated:(NSUInteger)bytesTruncated
{
    self = [super init];
    if (self != nil) {
        _product = product;
        _referrer = referrer;
        _quantity = quantity;
        _revenue = revenue;
        _bytesTruncated = bytesTruncated;
    }
    return self;
}

@end

@implementation AMAECommerceOrder

- (instancetype)initWithIdentifier:(NSString *)identifier
                         cartItems:(NSArray<AMAECommerceCartItem *> *)cartItems
{
    return [self initWithIdentifier:identifier
                          cartItems:cartItems
                            payload:nil];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                         cartItems:(NSArray<AMAECommerceCartItem *> *)cartItems
                           payload:(NSDictionary<NSString *, NSString *> *)payload
{
    return [self initWithIdentifier:identifier
                          cartItems:cartItems
                    internalPayload:[[AMAECommercePayload alloc] initWithPairs:payload truncatedPairsCount:0]];
}

- (instancetype)initWithIdentifier:(NSString *)identifier
                         cartItems:(NSArray<AMAECommerceCartItem *> *)cartItems
                   internalPayload:(AMAECommercePayload *)internalPayload
{
    self = [super init];
    if (self != nil) {
        _identifier = [identifier copy];
        _cartItems = [cartItems copy];
        _internalPayload = internalPayload;
    }
    return self;
}

- (NSDictionary<NSString *,id> *)payload
{
    return self.internalPayload.pairs;
}

@end

@implementation AMAECommerce

+ (instancetype)showScreenEventWithScreen:(AMAECommerceScreen *)screen
{
    return [[AMAECommerce alloc] initWithEventType:AMAECommerceEventTypeScreen
                                            screen:screen
                                           product:nil
                                          referrer:nil
                                          cartItem:nil
                                             order:nil
                                    bytesTruncated:0];
}

+ (instancetype)showProductCardEventWithProduct:(AMAECommerceProduct *)product
                                         screen:(AMAECommerceScreen *)screen
{
    return [[AMAECommerce alloc] initWithEventType:AMAECommerceEventTypeProductCard
                                            screen:screen
                                           product:product
                                          referrer:nil
                                          cartItem:nil
                                             order:nil
                                    bytesTruncated:0];
}

+ (instancetype)showProductDetailsEventWithProduct:(AMAECommerceProduct *)product
                                          referrer:(AMAECommerceReferrer *)referrer
{
    return [[AMAECommerce alloc] initWithEventType:AMAECommerceEventTypeProductDetails
                                            screen:nil
                                           product:product
                                          referrer:referrer
                                          cartItem:nil
                                             order:nil
                                    bytesTruncated:0];
}

+ (instancetype)addCartItemEventWithItem:(AMAECommerceCartItem *)item
{
    return [[AMAECommerce alloc] initWithEventType:AMAECommerceEventTypeAddToCart
                                            screen:nil
                                           product:nil
                                          referrer:nil
                                          cartItem:item
                                             order:nil
                                    bytesTruncated:0];
}

+ (instancetype)removeCartItemEventWithItem:(AMAECommerceCartItem *)item
{
    return [[AMAECommerce alloc] initWithEventType:AMAECommerceEventTypeRemoveFromCart
                                            screen:nil
                                           product:nil
                                          referrer:nil
                                          cartItem:item
                                             order:nil
                                    bytesTruncated:0];
}

+ (instancetype)beginCheckoutEventWithOrder:(AMAECommerceOrder *)order
{
    return [[AMAECommerce alloc] initWithEventType:AMAECommerceEventTypeBeginCheckout
                                            screen:nil
                                           product:nil
                                          referrer:nil
                                          cartItem:nil
                                             order:order
                                    bytesTruncated:0];
}

+ (instancetype)purchaseEventWithOrder:(AMAECommerceOrder *)order
{
    return [[AMAECommerce alloc] initWithEventType:AMAECommerceEventTypePurchase
                                            screen:nil
                                           product:nil
                                          referrer:nil
                                          cartItem:nil
                                             order:order
                                    bytesTruncated:0];
}

- (instancetype)initWithEventType:(AMAECommerceEventType)eventType
                           screen:(AMAECommerceScreen *)screen
                          product:(AMAECommerceProduct *)product
                         referrer:(AMAECommerceReferrer *)referrer
                         cartItem:(AMAECommerceCartItem *)cartItem
                            order:(AMAECommerceOrder *)order
                   bytesTruncated:(NSUInteger)bytesTruncated
{
    self = [super init];
    if (self != nil) {
        _eventType = eventType;
        _screen = screen;
        _product = product;
        _referrer = referrer;
        _cartItem = cartItem;
        _order = order;
        _bytesTruncated = bytesTruncated;
    }
    return self;
}

@end
