
#import <StoreKit/StoreKit.h>
#import "AMAPurchasesDefines.h"

@class AMATransactionObserver;

@protocol AMATransactionObserverDelegate<NSObject>

- (void)transactionObserver:(AMATransactionObserver *)observer
      didCaptureTransaction:(SKPaymentTransaction *)transaction
                  withState:(AMATransactionState)state;

@end

@interface AMATransactionObserver : NSObject <SKPaymentTransactionObserver>

@property (nonatomic, weak, readonly) id<AMATransactionObserverDelegate> delegate;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithDelegate:(id<AMATransactionObserverDelegate>)delegate;

- (void)startObservingTransactions;
- (void)stopObservingTransactions;

@end
