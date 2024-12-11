
#import <StoreKit/StoreKit.h>
#import "AMAPurchasesDefines.h"

@class AMAProductRequestor;

@protocol AMAProductRequestorDelegate<NSObject>

- (void)productRequestor:(AMAProductRequestor *)requestor didRecieveProduct:(SKProduct *)product;

- (void)productRequestorDidFailToFetchProduct:(AMAProductRequestor *)requestor;

@end

@interface AMAProductRequestor : NSObject<SKProductsRequestDelegate>

@property (nonatomic, strong, readonly) SKPaymentTransaction *transaction;
@property (nonatomic, weak, readonly) id<AMAProductRequestorDelegate> delegate;

@property (nonatomic, assign, readonly) AMATransactionState transactionState;

- (instancetype)initWithTransaction:(SKPaymentTransaction *)transaction
                   transactionState:(AMATransactionState)state
                           delegate:(id<AMAProductRequestorDelegate>)delegate;

- (void)requestProductInformation;

@end
