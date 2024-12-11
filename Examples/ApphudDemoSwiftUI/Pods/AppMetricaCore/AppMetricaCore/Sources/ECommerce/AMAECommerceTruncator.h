
#import <Foundation/Foundation.h>

@class AMAECommerce;
@protocol AMAStringTruncating;

@interface AMAECommerceTruncator : NSObject

@property (nonatomic, strong, readonly) id<AMAStringTruncating> screenNameTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> screenSearchQueryTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> productSKUTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> productNameTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> referrerTypeTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> referrerIdentifierTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> orderIdentifierTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> payloadKeyTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> payloadValueTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> amountUnitTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> categoryComponentTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> promoCodeTruncator;

@property (nonatomic, assign, readonly) NSUInteger maxPayloadSize;
@property (nonatomic, assign, readonly) NSUInteger maxInternalPriceComponentsCount;
@property (nonatomic, assign, readonly) NSUInteger maxCategoryComponentsCount;
@property (nonatomic, assign, readonly) NSUInteger maxPromoCodesCount;

- (AMAECommerce *)truncatedECommerce:(AMAECommerce *)value;

@end
