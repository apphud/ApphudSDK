
#import "AMACore.h"
#import "AMAECommerceTruncator.h"
#import "AMAECommerce+Internal.h"

static NSUInteger const kAMADecimalBytesSize = 12;

@implementation AMAECommerceTruncator

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _screenNameTruncator = [[AMALengthStringTruncator alloc] initWithMaxLength:100];
        _screenSearchQueryTruncator = [[AMALengthStringTruncator alloc] initWithMaxLength:1000];
        _productSKUTruncator = [[AMALengthStringTruncator alloc] initWithMaxLength:100];
        _productNameTruncator = [[AMALengthStringTruncator alloc] initWithMaxLength:1000];
        _referrerTypeTruncator = [[AMALengthStringTruncator alloc] initWithMaxLength:100];
        _referrerIdentifierTruncator = [[AMALengthStringTruncator alloc] initWithMaxLength:2 * 1024];
        _orderIdentifierTruncator = [[AMALengthStringTruncator alloc] initWithMaxLength:100];
        _payloadKeyTruncator = [[AMALengthStringTruncator alloc] initWithMaxLength:100];
        _payloadValueTruncator = [[AMALengthStringTruncator alloc] initWithMaxLength:1000];
        _amountUnitTruncator = [[AMALengthStringTruncator alloc] initWithMaxLength:20];
        _categoryComponentTruncator = [[AMALengthStringTruncator alloc] initWithMaxLength:100];
        _promoCodeTruncator = [[AMALengthStringTruncator alloc] initWithMaxLength:100];

        _maxPayloadSize = 20 * 1024;
        _maxInternalPriceComponentsCount = 30;
        _maxCategoryComponentsCount = 20;
        _maxPromoCodesCount = 20;
    }
    return self;
}

#pragma mark - Public -

- (AMAECommerce *)truncatedECommerce:(AMAECommerce *)value
{
    NSUInteger bytesTruncated = 0;
    return [[AMAECommerce alloc] initWithEventType:value.eventType
                                            screen:[self truncatedScreen:value.screen bytesTruncated:&bytesTruncated]
                                           product:[self truncatedProduct:value.product bytesTruncated:&bytesTruncated]
                                          referrer:[self truncatedReferrer:value.referrer bytesTruncated:&bytesTruncated]
                                          cartItem:[self truncatedCartItem:value.cartItem bytesTruncated:&bytesTruncated]
                                             order:[self truncatedOrder:value.order bytesTruncated:&bytesTruncated]
                                    bytesTruncated:bytesTruncated];
}

#pragma mark - Private -

- (AMAECommerceScreen *)truncatedScreen:(AMAECommerceScreen *)screen
                         bytesTruncated:(NSUInteger *)bytesTruncated
{
    if (screen == nil) {
        return nil;
    }

    NSString *name = [self.screenNameTruncator truncatedString:screen.name
                                                  onTruncation:[self onTruncation:bytesTruncated]];
    NSArray *categoryComponents = [self truncatedCategoryComponents:screen.categoryComponents
                                                     bytesTruncated:bytesTruncated];
    NSString *searchQuery = [self.screenSearchQueryTruncator truncatedString:screen.searchQuery
                                                                onTruncation:[self onTruncation:bytesTruncated]];
    AMAECommercePayload *internalPayload = [self truncatedPayload:screen.internalPayload
                                                   bytesTruncated:bytesTruncated];
    return [[AMAECommerceScreen alloc] initWithName:name
                                 categoryComponents:categoryComponents
                                        searchQuery:searchQuery
                                    internalPayload:internalPayload];
}

- (AMAECommerceProduct *)truncatedProduct:(AMAECommerceProduct *)product
                           bytesTruncated:(NSUInteger *)bytesTruncated
{
    if (product == nil) {
        return nil;
    }

    NSString *sku = [self.productSKUTruncator truncatedString:product.sku
                                                 onTruncation:[self onTruncation:bytesTruncated]];
    NSString *name = [self.productNameTruncator truncatedString:product.name
                                                   onTruncation:[self onTruncation:bytesTruncated]];
    NSArray *categoryComponents = [self truncatedCategoryComponents:product.categoryComponents
                                                     bytesTruncated:bytesTruncated];
    AMAECommercePayload *internalPayload = [self truncatedPayload:product.internalPayload
                                                   bytesTruncated:bytesTruncated];
    AMAECommercePrice *actualPrice = [self truncatedPrice:product.actualPrice
                                           bytesTruncated:bytesTruncated];
    AMAECommercePrice *originalPrice = [self truncatedPrice:product.originalPrice
                                             bytesTruncated:bytesTruncated];
    NSArray *promoCodes = [self truncatedPromoСodes:product.promoCodes
                                     bytesTruncated:bytesTruncated];
    return [[AMAECommerceProduct alloc] initWithSKU:sku
                                               name:name
                                 categoryComponents:categoryComponents
                                    internalPayload:internalPayload
                                        actualPrice:actualPrice
                                      originalPrice:originalPrice
                                         promoCodes:promoCodes];
}

- (AMAECommerceReferrer *)truncatedReferrer:(AMAECommerceReferrer *)referrer
                             bytesTruncated:(NSUInteger *)bytesTruncated
{
    if (referrer == nil) {
        return nil;
    }

    NSString *type = [self.referrerTypeTruncator truncatedString:referrer.type
                                                    onTruncation:[self onTruncation:bytesTruncated]];
    NSString *identifier = [self.referrerIdentifierTruncator truncatedString:referrer.identifier
                                                                onTruncation:[self onTruncation:bytesTruncated]];
    AMAECommerceScreen *screen = [self truncatedScreen:referrer.screen
                                        bytesTruncated:bytesTruncated];

    return [[AMAECommerceReferrer alloc] initWithType:type
                                           identifier:identifier
                                               screen:screen];
}

- (AMAECommerceCartItem *)truncatedCartItem:(AMAECommerceCartItem *)cartItem
                             bytesTruncated:(NSUInteger *)bytesTruncated
{
    if (cartItem == nil) {
        return nil;
    }

    NSUInteger localBytesTruncated = 0;
    AMAECommerceProduct *product = [self truncatedProduct:cartItem.product
                                           bytesTruncated:&localBytesTruncated];
    AMAECommerceReferrer *referrer = [self truncatedReferrer:cartItem.referrer
                                              bytesTruncated:&localBytesTruncated];
    AMAECommercePrice *revenue = [self truncatedPrice:cartItem.revenue
                                       bytesTruncated:&localBytesTruncated];

    if (bytesTruncated != NULL) {
        *bytesTruncated += localBytesTruncated;
    }
    return [[AMAECommerceCartItem alloc] initWithProduct:product
                                                referrer:referrer
                                                quantity:cartItem.quantity
                                                 revenue:revenue
                                          bytesTruncated:localBytesTruncated];
}

- (AMAECommerceOrder *)truncatedOrder:(AMAECommerceOrder *)order
                       bytesTruncated:(NSUInteger *)bytesTruncated
{
    if (order == nil) {
        return nil;
    }

    NSString *identifier = [self.orderIdentifierTruncator truncatedString:order.identifier
                                                             onTruncation:[self onTruncation:bytesTruncated]];
    NSArray *cartItems = [AMACollectionUtilities mapArray:order.cartItems withBlock:^id(AMAECommerceCartItem *cartItem) {
        return [self truncatedCartItem:cartItem
                        bytesTruncated:bytesTruncated];
    }];
    AMAECommercePayload *internalPayload = [self truncatedPayload:order.internalPayload
                                                   bytesTruncated:bytesTruncated];
    
    return [[AMAECommerceOrder alloc] initWithIdentifier:identifier
                                               cartItems:cartItems
                                         internalPayload:internalPayload];
}

- (AMAECommercePayload *)truncatedPayload:(AMAECommercePayload *)payload
                           bytesTruncated:(NSUInteger *)bytesTruncated
{
    if (payload.pairs.count == 0) {
        return nil;
    }

    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    NSMutableDictionary<NSString *, NSString *> *payloadWithTruncatedKeys = [NSMutableDictionary dictionary];
    [payload.pairs enumerateKeysAndObjectsUsingBlock:^(NSString *key, NSString *value, BOOL *stop) {
        NSString *truncatedKey = [self.payloadKeyTruncator truncatedString:key
                                                              onTruncation:[self onTruncation:bytesTruncated]];
        payloadWithTruncatedKeys[truncatedKey] = value;
    }];
    NSArray *sortedKeys =
        [payloadWithTruncatedKeys.allKeys sortedArrayUsingComparator:^NSComparisonResult(NSString *lhs, NSString *rhs) {
            return [@(payloadWithTruncatedKeys[lhs].length) compare:@(payloadWithTruncatedKeys[rhs].length)];
        }];

    NSUInteger totalSize = 0;
    NSUInteger truncatedPairsCount = 0;
    NSUInteger localBytesTruncated = 0;
    for (NSString *key in sortedKeys) {
        NSString *value = [self.payloadValueTruncator truncatedString:payloadWithTruncatedKeys[key]
                                                         onTruncation:[self onTruncation:bytesTruncated]];
        NSUInteger pairSize =
            [key lengthOfBytesUsingEncoding:NSUTF8StringEncoding]
            + [value lengthOfBytesUsingEncoding:NSUTF8StringEncoding];

        if (totalSize + pairSize <= self.maxPayloadSize) {
            result[key] = value;
            totalSize += pairSize;
        }
        else {
            truncatedPairsCount += 1;
            localBytesTruncated += pairSize;
        }
    }

    if (bytesTruncated != NULL) {
        *bytesTruncated += localBytesTruncated;
    }

    return [[AMAECommercePayload alloc] initWithPairs:[result copy]
                                  truncatedPairsCount:payload.truncatedPairsCount + truncatedPairsCount];
}

- (AMAECommercePrice *)truncatedPrice:(AMAECommercePrice *)price
                       bytesTruncated:(NSUInteger *)bytesTruncated
{
    if (price == nil) {
        return nil;
    }

    AMAECommerceAmount *fiat = [self truncatedAmount:price.fiat
                                      bytesTruncated:bytesTruncated];
    NSArray *internalComponents = [self truncatedArray:price.internalComponents
                                       itemsCountLimit:self.maxInternalPriceComponentsCount
                                        bytesTruncated:bytesTruncated
                                          sizeProvider:^NSUInteger(AMAECommerceAmount *item) {
        return kAMADecimalBytesSize + [item.unit lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    }
                                         itemTruncator:^id(id item) {
        return [self truncatedAmount:item bytesTruncated:bytesTruncated];
    }];
    return [[AMAECommercePrice alloc] initWithFiat:fiat internalComponents:internalComponents];
}

- (AMAECommerceAmount *)truncatedAmount:(AMAECommerceAmount *)amount
                         bytesTruncated:(NSUInteger *)bytesTruncated
{
    if (amount == nil) {
        return nil;
    }

    NSString *unit = [self.amountUnitTruncator truncatedString:amount.unit
                                                  onTruncation:[self onTruncation:bytesTruncated]];
    return [[AMAECommerceAmount alloc] initWithUnit:unit value:amount.value];
}

- (NSArray *)truncatedCategoryComponents:(NSArray *)categoryComponents
                          bytesTruncated:(NSUInteger *)bytesTruncated
{
    return [self truncatedArray:categoryComponents
                itemsCountLimit:self.maxCategoryComponentsCount
                 bytesTruncated:bytesTruncated
                   sizeProvider:^NSUInteger(NSString *item) {
        return [item lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    }
                  itemTruncator:^id(id item) {
        return [self.categoryComponentTruncator truncatedString:item
                                                   onTruncation:[self onTruncation:bytesTruncated]];
    }];
}

- (NSArray *)truncatedPromoСodes:(NSArray *)promoCodes
                  bytesTruncated:(NSUInteger *)bytesTruncated
{
    return [self truncatedArray:promoCodes
                itemsCountLimit:self.maxPromoCodesCount
                 bytesTruncated:bytesTruncated
                   sizeProvider:^NSUInteger(NSString *item) {
        return [item lengthOfBytesUsingEncoding:NSUTF8StringEncoding];
    }
                  itemTruncator:^id(id item) {
        return [self.promoCodeTruncator truncatedString:item
                                           onTruncation:[self onTruncation:bytesTruncated]];
    }];
}

- (NSArray *)truncatedArray:(NSArray *)array
            itemsCountLimit:(NSUInteger)itemsCountLimit
             bytesTruncated:(NSUInteger *)bytesTruncated
               sizeProvider:(NSUInteger (^)(id item))sizeProvider
              itemTruncator:(id (^)(id item))truncator
{
    if (array.count == 0) {
        return nil;
    }

    NSMutableArray *result = [NSMutableArray arrayWithCapacity:MIN(array.count, itemsCountLimit)];
    NSUInteger localBytesTruncated = 0;
    for (NSString *item in array) {
        if (result.count < itemsCountLimit) {
            NSString *truncatedItem = truncator == nil ? item : truncator(item);
            if (truncatedItem != nil) {
                [result addObject:truncatedItem];
            }
        }
        else {
            localBytesTruncated += sizeProvider == nil ? 0 : sizeProvider(item);
        }
    }

    if (bytesTruncated != NULL) {
        *bytesTruncated += localBytesTruncated;
    }
    return [result copy];
}

- (AMATruncationBlock)onTruncation:(NSUInteger *)counter
{
    return ^(NSUInteger bytesTruncated) {
        if (counter != NULL) {
            *counter += bytesTruncated;
        }
    };
}

@end
