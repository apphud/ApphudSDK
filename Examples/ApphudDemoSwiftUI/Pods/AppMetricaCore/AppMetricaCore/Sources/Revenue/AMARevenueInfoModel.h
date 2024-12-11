
#import <Foundation/Foundation.h>
#import "AMAPurchasesDefines.h"

@class AMASubscriptionInfoModel;
@class AMATransactionInfoModel;

@interface AMARevenueInfoModel : NSObject

@property (nonatomic, strong, readonly) NSDecimalNumber *priceDecimal;
@property (nonatomic, copy, readonly) NSString *currency;
@property (nonatomic, assign, readonly) NSUInteger quantity;
@property (nonatomic, copy, readonly) NSString *productID;
@property (nonatomic, copy, readonly) NSString *transactionID;
@property (nonatomic, copy, readonly) NSData *receiptData;
@property (nonatomic, copy, readonly) NSString *payloadString;
@property (nonatomic, assign, readonly) NSUInteger bytesTruncated;
// Auto-in-app-purchases types
@property (nonatomic, assign, readonly) BOOL isAutoCollected;
@property (nonatomic, assign, readonly) AMAInAppType inAppType;
@property (nonatomic, strong, readonly) AMASubscriptionInfoModel *subscriptionInfo;
@property (nonatomic, strong, readonly) AMATransactionInfoModel *transactionInfo;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

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
                     transactionInfo:(AMATransactionInfoModel *)transactionInfo;

@end
