
#import "AMACore.h"
#import "AMARevenueInfoConverter.h"
#import "AMARevenueInfoModel.h"
#import "AMARevenueInfo.h"

@implementation AMARevenueInfoConverter

+ (AMARevenueInfoModel *)convertRevenueInfo:(AMARevenueInfo *)revenueInfo
                                      error:(NSError **)error
{
    NSString *payloadString = [AMAJSONSerialization stringWithJSONObject:revenueInfo.payload error:error];
    AMARevenueInfoModel *model = [[AMARevenueInfoModel alloc] initWithPriceDecimal:revenueInfo.priceDecimal
                                                                          currency:revenueInfo.currency
                                                                          quantity:revenueInfo.quantity
                                                                         productID:revenueInfo.productID
                                                                     transactionID:revenueInfo.transactionID
                                                                       receiptData:revenueInfo.receiptData
                                                                     payloadString:payloadString
                                                                    bytesTruncated:0
                                                                   isAutoCollected:NO
                                                                         inAppType:AMAInAppTypePurchase
                                                                  subscriptionInfo:nil
                                                                   transactionInfo:nil];
    return model;
}

@end
