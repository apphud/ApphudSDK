
#import "AMATransactionObserver.h"
#import "AMAMetricaDynamicFrameworks.h"

@interface AMATransactionObserver ()

@property (nonatomic, assign) BOOL isObserving;
@property (nonatomic, strong, readonly) AMAFramework *storeKit;

@end

@implementation AMATransactionObserver

- (instancetype)initWithDelegate:(id<AMATransactionObserverDelegate>)delegate
{
    self = [super init];
    if (self != nil) {
        _delegate = delegate;
        _isObserving = NO;
        _storeKit = AMAMetricaDynamicFrameworks.storeKit;
    }
    return self;
}

- (void)dealloc
{
    [self.defaultPaymentQueue removeTransactionObserver:self];
}

#pragma mark - Public -

- (void)startObservingTransactions
{
    if (self.isObserving == NO) {
        @synchronized(self) {
            if (self.isObserving == NO) {
                [self.defaultPaymentQueue addTransactionObserver:self];
                self.isObserving = YES;
            }
        }
    }
}

- (void)stopObservingTransactions
{
    if (self.isObserving) {
        @synchronized(self) {
            if (self.isObserving) {
                [self.defaultPaymentQueue removeTransactionObserver:self];
                self.isObserving = NO;
            }
        }
    }
}

#pragma mark - Private -

- (SKPaymentQueue *)defaultPaymentQueue
{
    return [[self.storeKit classFromString:@"SKPaymentQueue"] defaultQueue];
}

#pragma mark - SKPaymentTransactionObserver

- (void)paymentQueue:(SKPaymentQueue *)queue
 updatedTransactions:(NSArray<SKPaymentTransaction *> *)transactions
{
    for (SKPaymentTransaction *transaction in transactions) {
        switch (transaction.transactionState) {
            case SKPaymentTransactionStatePurchased:
                [self.delegate transactionObserver:self
                             didCaptureTransaction:transaction
                                         withState:AMATransactionStatePurchased];
                break;
            case SKPaymentTransactionStateRestored:
                [self.delegate transactionObserver:self
                             didCaptureTransaction:transaction
                                         withState:AMATransactionStateRestored];
                break;
            default:
                break;
        }
    }
}

@end
