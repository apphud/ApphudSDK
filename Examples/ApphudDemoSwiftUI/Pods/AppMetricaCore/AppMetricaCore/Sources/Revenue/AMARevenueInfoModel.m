
#import "AMARevenueInfoModel.h"

@interface AMARevenueInfoModel ()

@property (nonatomic, strong, readwrite) NSDecimalNumber *priceDecimal;
@property (nonatomic, copy, readwrite) NSString *currency;
@property (nonatomic, assign, readwrite) NSUInteger quantity;
@property (nonatomic, copy, readwrite) NSString *productID;
@property (nonatomic, copy, readwrite) NSString *transactionID;
@property (nonatomic, copy, readwrite) NSData *receiptData;
@property (nonatomic, copy, readwrite) NSString *payloadString;
@property (nonatomic, assign, readwrite) NSUInteger bytesTruncated;
// Auto-in-app-purchases types
@property (nonatomic, assign, readwrite) BOOL isAutoCollected;
@property (nonatomic, assign, readwrite) AMAInAppType inAppType;
@property (nonatomic, strong, readwrite) AMASubscriptionInfoModel *subscriptionInfo;
@property (nonatomic, strong, readwrite) AMATransactionInfoModel *transactionInfo;

@end

@implementation AMARevenueInfoModel

- (instancetype)initWithPriceDecimal:(NSDecimalNumber *)priceDecimal
                            currency:(NSString *)currency
                            quantity:(NSUInteger)quantity
                           productID:(NSString *)productID
                       transactionID:(NSString *)transactionID
                         receiptData:(NSData *)receiptData
                       payloadString:(NSString *)payloadString
                      bytesTruncated:(NSUInteger)bytesTruncated
                     isAutoCollected:(BOOL)isAutoCollected
                           inAppType:(AMAInAppType)inAppType
                    subscriptionInfo:(AMASubscriptionInfoModel *)subscriptionInfo
                     transactionInfo:(AMATransactionInfoModel *)transactionInfo
{
    self = [super init];
    if (self != nil) {
        _priceDecimal = priceDecimal;
        _currency = [currency copy];
        _quantity = quantity;
        _productID = [productID copy];
        _transactionID = [transactionID copy];
        _receiptData = [receiptData copy];
        _payloadString = [payloadString copy];
        _bytesTruncated = bytesTruncated;
        _inAppType = inAppType;
        _subscriptionInfo = subscriptionInfo;
        _transactionInfo = transactionInfo;
        _isAutoCollected = isAutoCollected;
    }

    return self;
}

@end
