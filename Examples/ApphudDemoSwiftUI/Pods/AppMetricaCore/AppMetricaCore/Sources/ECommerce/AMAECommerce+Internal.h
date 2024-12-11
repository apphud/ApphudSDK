
#import "AMAECommerce.h"

@interface AMAECommercePayload : NSObject

@property (nonatomic, copy, readonly) NSDictionary<NSString *, NSString *> *pairs;
@property (nonatomic, assign, readonly) NSUInteger truncatedPairsCount;

- (instancetype)init NS_UNAVAILABLE;
- (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithPairs:(NSDictionary<NSString *, NSString *> *)pairs
          truncatedPairsCount:(NSUInteger)truncatedPairsCount;

@end

@interface AMAECommerceScreen ()

@property (nonatomic, strong, readonly) AMAECommercePayload *internalPayload;

- (instancetype)initWithName:(NSString *)name
          categoryComponents:(NSArray<NSString *> *)categoryComponents
                 searchQuery:(NSString *)searchQuery
             internalPayload:(AMAECommercePayload *)internalPayload;

@end

@interface AMAECommerceProduct ()

@property (nonatomic, strong, readonly) AMAECommercePayload *internalPayload;

- (instancetype)initWithSKU:(NSString *)sku
                       name:(NSString *)name
         categoryComponents:(NSArray<NSString *> *)categoryComponents
            internalPayload:(AMAECommercePayload *)internalPayload
                actualPrice:(AMAECommercePrice *)actualPrice
              originalPrice:(AMAECommercePrice *)originalPrice
                 promoCodes:(NSArray<NSString *> *)promoCodes;

@end

@interface AMAECommerceCartItem ()

@property (nonatomic, assign, readonly) NSUInteger bytesTruncated;

- (instancetype)initWithProduct:(AMAECommerceProduct *)product
                       referrer:(AMAECommerceReferrer *)referrer
                       quantity:(NSDecimalNumber *)quantity
                        revenue:(AMAECommercePrice *)revenue
                 bytesTruncated:(NSUInteger)bytesTruncated;

@end

@interface AMAECommerceOrder ()

@property (nonatomic, strong, readonly) AMAECommercePayload *internalPayload;

- (instancetype)initWithIdentifier:(NSString *)identifier
                         cartItems:(NSArray<AMAECommerceCartItem *> *)cartItems
                   internalPayload:(AMAECommercePayload *)internalPayload;

@end

typedef NS_ENUM(NSUInteger, AMAECommerceEventType) {
    AMAECommerceEventTypeScreen,
    AMAECommerceEventTypeProductCard,
    AMAECommerceEventTypeProductDetails,
    AMAECommerceEventTypeAddToCart,
    AMAECommerceEventTypeRemoveFromCart,
    AMAECommerceEventTypeBeginCheckout,
    AMAECommerceEventTypePurchase,
};

@interface AMAECommerce ()

@property (nonatomic, assign, readonly) AMAECommerceEventType eventType;

@property (nonatomic, strong, readonly) AMAECommerceScreen *screen;
@property (nonatomic, strong, readonly) AMAECommerceProduct *product;
@property (nonatomic, strong, readonly) AMAECommerceReferrer *referrer;
@property (nonatomic, strong, readonly) AMAECommerceCartItem *cartItem;
@property (nonatomic, strong, readonly) AMAECommerceOrder *order;

@property (nonatomic, assign, readonly) NSUInteger bytesTruncated;

- (instancetype)initWithEventType:(AMAECommerceEventType)eventType
                           screen:(AMAECommerceScreen *)screen
                          product:(AMAECommerceProduct *)product
                         referrer:(AMAECommerceReferrer *)referrer
                         cartItem:(AMAECommerceCartItem *)cartItem
                            order:(AMAECommerceOrder *)order
                   bytesTruncated:(NSUInteger)bytesTruncated;

@end
