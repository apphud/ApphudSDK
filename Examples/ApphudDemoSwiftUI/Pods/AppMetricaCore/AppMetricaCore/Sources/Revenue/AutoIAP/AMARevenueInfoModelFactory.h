
#import <Foundation/Foundation.h>
#import "AMAPurchasesDefines.h"

@class AMARevenueInfoModel;
@class SKPaymentTransaction;
@class SKProduct;

@interface AMARevenueInfoModelFactory : NSObject

- (AMARevenueInfoModel *)revenueInfoModelWithTransaction:(SKPaymentTransaction *)transaction
                                                   state:(AMATransactionState)state
                                                 product:(SKProduct *)product;

@end

