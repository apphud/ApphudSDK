
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

/**
 * Describes an amount of something - number and unit.
 */
NS_SWIFT_NAME(ECommerceAmount)
@interface AMAECommerceAmount : NSObject

/**
 * Amount unit. For example, "USD", "RUB", etc.
 */
@property (nonatomic, copy, readonly) NSString *unit; // 20 chars
/**
 * Amount value.
 */
@property (nonatomic, strong, readonly) NSDecimalNumber *value;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 * Creates an amount with its value.
 *
 * @param unit Amount unit. For example, "USD", "RUB", etc.
 * @param value Amount value.
 * @return An instance of AMAECommerceAmount.
 */
- (instancetype)initWithUnit:(NSString *)unit value:(NSDecimalNumber *)value;

@end

/**
 * Describes price of a product.
 */
NS_SWIFT_NAME(ECommercePrice)
@interface AMAECommercePrice : NSObject

/**
 * Amount in fiat money.
 */
@property (nonatomic, strong, readonly) AMAECommerceAmount *fiat;
/**
 * Price internal components - amounts in internal currency.
 */
@property (nonatomic, copy, readonly, nullable) NSArray<AMAECommerceAmount *> *internalComponents; // 30 items

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 * Creates a price.
 *
 * @param fiat Amount in fiat money.
 * @return An instance of AMAECommercePrice.
 */
- (instancetype)initWithFiat:(AMAECommerceAmount *)fiat;

/**
 * Creates a price.
 *
 * @param fiat Amount in fiat money.
 * @param internalComponents price internal components - amounts in internal currency.
 * @return An instance of AMAECommercePrice.
 */
- (instancetype)initWithFiat:(AMAECommerceAmount *)fiat
          internalComponents:(nullable NSArray<AMAECommerceAmount *> *)internalComponents;

@end

/**
 * Describes a screen (page).
 */
NS_SWIFT_NAME(ECommerceScreen)
@interface AMAECommerceScreen : NSObject

/**
 * Name of the screen.
 */
@property (nonatomic, copy, readonly, nullable) NSString *name; // 100 chars
/**
 * Categories path - path to the screen.
 */
@property (nonatomic, copy, readonly, nullable) NSArray<NSString *> *categoryComponents; // 20 items * 100 chars
/**
 * Search query.
 */
@property (nonatomic, copy, readonly, nullable) NSString *searchQuery; // 1000 chars
/**
 * Payload - additional key-value structured data with various content.
 */
@property (nonatomic, copy, readonly, nullable) NSDictionary<NSString *, NSString *> *payload; // 20 Kb / k=100 chars v=1000 chars

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 * Creates screen.
 *
 * @param name Name of the screen.
 * @return An instance of AMAECommerceScreen.
 */
- (instancetype)initWithName:(NSString *)name;

/**
 * Creates screen.
 *
 * @param categoryComponents Categories path - path to the screen.
 * @return An instance of AMAECommerceScreen.
 */
- (instancetype)initWithCategoryComponents:(NSArray<NSString *> *)categoryComponents;

/**
 * Creates screen.
 *
 * @param searchQuery Search query.
 * @return An instance of AMAECommerceScreen.
 */
- (instancetype)initWithSearchQuery:(NSString *)searchQuery;

/**
 * Creates screen.
 *
 * @param payload Payload - additional key-value structured data with various content.
 * @return An instance of AMAECommerceScreen.
 */
- (instancetype)initWithPayload:(NSDictionary<NSString *, NSString *> *)payload;

/**
 * Creates screen.
 *
 * @param name Name of the screen.
 * @param categoryComponents Categories path - path to the screen.
 * @param searchQuery Search query.
 * @param payload Payload - additional key-value structured data with various content.
 * @return An instance of AMAECommerceScreen.
 */
- (instancetype)initWithName:(nullable NSString *)name
          categoryComponents:(nullable NSArray<NSString *> *)categoryComponents
                 searchQuery:(nullable NSString *)searchQuery
                     payload:(nullable NSDictionary<NSString *, NSString *> *)payload;

@end

/**
 * Describes a product.
 */
NS_SWIFT_NAME(ECommerceProduct)
@interface AMAECommerceProduct : NSObject

/**
 * Product SKU (Stock Keeping Unit).
 */
@property (nonatomic, copy, readonly) NSString *sku; // 100 chars
/**
 * Name of the product.
 */
@property (nonatomic, copy, readonly, nullable) NSString *name; // 1000 chars
/**
 * Categories-wise path to the product.
 */
@property (nonatomic, copy, readonly, nullable) NSArray<NSString *> *categoryComponents; // 20 items * 100 chars

/**
 * Payload - additional key-value structured data with various content.
 */
@property (nonatomic, copy, readonly, nullable) NSDictionary<NSString *, NSString *> *payload; // 20 Kb / k=100 chars v=1000 chars

/**
 * Actual price of the product - price after all discounts and promocodes are applied.
 */
@property (nonatomic, strong, readonly, nullable) AMAECommercePrice *actualPrice;
/**
 * Original price of the product.
 */
@property (nonatomic, strong, readonly, nullable) AMAECommercePrice *originalPrice;

/**
 * List of promocodes applied to the product.
 */
@property (nonatomic, copy, readonly, nullable) NSArray<NSString *> *promoCodes; // 20 items * 100 chars

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 * Creates a product.
 *
 * @param sku Product SKU (Stock Keeping Unit).
 * @return An instance of AMAECommerceProduct.
 */
- (instancetype)initWithSKU:(NSString *)sku;

/**
 * Creates a product.
 *
 * @param sku Product SKU (Stock Keeping Unit).
 * @param name Name of the product.
 * @param categoryComponents Categories-wise path to the product.
 * @param payload Payload - additional key-value structured data with various content.
 * @param actualPrice Actual price of the product - price after all discounts and promocodes are applied.
 * @param originalPrice Original price of the product.
 * @param promoCodes List of promocodes applied to the product.
 * @return An instance of AMAECommerceProduct.
 */
- (instancetype)initWithSKU:(NSString *)sku
                       name:(nullable NSString *)name
         categoryComponents:(nullable NSArray<NSString *> *)categoryComponents
                    payload:(nullable NSDictionary<NSString *, NSString *> *)payload
                actualPrice:(nullable AMAECommercePrice *)actualPrice
              originalPrice:(nullable AMAECommercePrice *)originalPrice
                 promoCodes:(nullable NSArray<NSString *> *)promoCodes;

@end

/**
 * Describes transition source - screen which shown screen, product card, etc.
 */
NS_SWIFT_NAME(ECommerceReferrer)
@interface AMAECommerceReferrer : NSObject

/**
 * Referrer type - type of object used to perform a transition. For example: "button", "banner", etc.
 */
@property (nonatomic, copy, readonly, nullable) NSString *type; // 100 chars
/**
 * Referrer identifier - identifier of object used to perform a transition.
 */
@property (nonatomic, copy, readonly, nullable) NSString *identifier; // 2048 chars
/**
 * Referrer screen - screen from which the transition started.
 */
@property (nonatomic, strong, readonly, nullable) AMAECommerceScreen *screen;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 * Creates referrer.
 *
 * @param type Referrer type - type of object used to perform a transition. For example: "button", "banner", etc.
 * @param identifier Referrer identifier - identifier of object used to perform a transition.
 * @param screen Referrer screen - screen from which the transition started.
 * @return An instance of AMAECommerceReferrer.
 */
- (instancetype)initWithType:(nullable NSString *)type
                  identifier:(nullable NSString *)identifier
                      screen:(nullable AMAECommerceScreen *)screen;

@end

/**
 * Describes an item in a cart.
 */
NS_SWIFT_NAME(ECommerceCartItem)
@interface AMAECommerceCartItem : NSObject

/**
 * Item product.
 */
@property (nonatomic, strong, readonly) AMAECommerceProduct *product;
/**
 * Quantity of item product.
 */
@property (nonatomic, strong, readonly) NSDecimalNumber *quantity;
/**
 * Total price of the cart item. Considers quantity, applied discounts, etc.
 */
@property (nonatomic, strong, readonly) AMAECommercePrice *revenue;
/**
 * Referrer: a way item was added to cart.
 */
@property (nonatomic, strong, readonly, nullable) AMAECommerceReferrer *referrer;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 * Creates cart item.
 *
 * @param product Item product.
 * @param quantity Quantity of item product.
 * @param revenue Total price of the cart item. Considers quantity, applied discounts, etc.
 * @param referrer Referrer: a way item was added to cart.
 * @return An instance of AMAECommerceCartItem.
 */
- (instancetype)initWithProduct:(AMAECommerceProduct *)product
                       quantity:(NSDecimalNumber *)quantity
                        revenue:(AMAECommercePrice *)revenue
                       referrer:(nullable AMAECommerceReferrer *)referrer;

@end

/**
 * Describes an order - info about a cart purchase.
 */
NS_SWIFT_NAME(ECommerceOrder)
@interface AMAECommerceOrder : NSObject

/**
 * Order identifier.
 */
@property (nonatomic, copy, readonly) NSString *identifier; // 100 chars
/**
 * List of items in the cart.
 */
@property (nonatomic, copy, readonly) NSArray<AMAECommerceCartItem *> *cartItems; // unlimited

/**
 * Payload - additional key-value structured data with various content.
 */
@property (nonatomic, copy, readonly, nullable) NSDictionary<NSString *, NSString *> *payload; // 20 Kb / k=100 chars v=1000 chars

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

/**
 * Creates order.
 *
 * @param identifier Order identifier.
 * @param cartItems List of items in the cart.
 * @return An instance of AMAECommerceOrder.
 */
- (instancetype)initWithIdentifier:(NSString *)identifier
                         cartItems:(NSArray<AMAECommerceCartItem *> *)cartItems;

/**
 * Creates order.
 *
 * @param identifier Order identifier.
 * @param cartItems List of items in the cart.
 * @param payload Payload - additional key-value structured data with various content.
 * @return An instance of AMAECommerceOrder.
 */
- (instancetype)initWithIdentifier:(NSString *)identifier
                         cartItems:(NSArray<AMAECommerceCartItem *> *)cartItems
                           payload:(nullable NSDictionary<NSString *, NSString *> *)payload;

@end

/**
 * Use class methods of this interface to form e-commerce event.
 * There are several different types of e-commerce events for different user actions.
 * Each method corresponds to one specific type. See method descriptions for more info.
 */
NS_SWIFT_NAME(ECommerce)
@interface AMAECommerce : NSObject

/**
 * Creates e-commerce ShowScreenEvent.
 * Use this event to report user opening some page: product list, search screen, main page, etc.
 *
 * @param screen  Screen that has been opened.
 * @return ShowScreenEvent.
 */
+ (instancetype)showScreenEventWithScreen:(AMAECommerceScreen *)screen
    NS_SWIFT_NAME(showScreenEvent(screen:));

/**
 * Creates e-commerce ShowProductCardEvent.
 * Use this event to report user viewing product card among others in a list.
 * Best practise is to consider product card viewed if it has been shown on screen for more than N seconds.
 *
 * @param product Product that has been viewed.
 * @param screen Screen where the product is shown.
 * @return ShowProductCardEvent.
 */
+ (instancetype)showProductCardEventWithProduct:(AMAECommerceProduct *)product
                                         screen:(AMAECommerceScreen *)screen
    NS_SWIFT_NAME(showProductCardEvent(product:screen:));

/**
 * Creates e-commerce ShowProductDetailsEvent.
 * Use this method to report user viewing product card by opening its own page.
 *
 * @param product Product that has been viewed.
 * @param referrer Info about the source of transition to shown product card.
 * @return ShowProductDetailsEvent.
 */
+ (instancetype)showProductDetailsEventWithProduct:(AMAECommerceProduct *)product
                                          referrer:(nullable AMAECommerceReferrer *)referrer
    NS_SWIFT_NAME(showProductDetailsEvent(product:referrer:));

/**
 * Creates e-commerce AddCartItemEvent.
 * Use this method to report user adding an item to cart.
 *
 * @param item  Item that has been added to cart.
 * @return AddCartItemEvent.
 */
+ (instancetype)addCartItemEventWithItem:(AMAECommerceCartItem *)item
    NS_SWIFT_NAME(addCartItemEvent(cartItem:));

/**
 * Creates e-commerce RemoveCartItemEvent.
 * Use this method to report user removing an item form cart.
 *
 * @param item Item that has been removed from cart.
 * @return RemoveCartItemEvent
 */
+ (instancetype)removeCartItemEventWithItem:(AMAECommerceCartItem *)item
    NS_SWIFT_NAME(removeCartItemEvent(cartItem:));

/**
 * Creates e-commerce BeginCheckoutEvent.
 * Use this event to report user begin checkout a purchase.
 *
 * @param order Various info about purchase.
 * @return BeginCheckoutEvent.
 */
+ (instancetype)beginCheckoutEventWithOrder:(AMAECommerceOrder *)order
    NS_SWIFT_NAME(beginCheckoutEvent(order:));

/**
 * Creates e-commerce PurchaseEvent.
 * Use this event to report user complete a purchase.
 *
 * @param order Various info about purchase.
 * @return PurchaseEvent.
 */
+ (instancetype)purchaseEventWithOrder:(AMAECommerceOrder *)order
    NS_SWIFT_NAME(purchaseEvent(order:));

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
