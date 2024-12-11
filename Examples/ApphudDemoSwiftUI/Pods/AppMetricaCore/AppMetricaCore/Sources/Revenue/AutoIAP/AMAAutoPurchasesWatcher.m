
#import "AMAAutoPurchasesWatcher.h"
#import "AMAReporter.h"
#import "AMARevenueInfoModel.h"
#import "AMARevenueInfoModelFactory.h"

@interface AMAAutoPurchasesWatcher ()

@property (atomic, strong) AMAReporter *reporter;
@property (nonatomic, strong, readonly) id<AMAAsyncExecuting> executor;
@property (nonatomic, strong, readonly) AMATransactionObserver *observer;
@property (nonatomic, strong, readonly) NSMutableSet *requesters;
@property (nonatomic, strong, readonly) AMARevenueInfoModelFactory *factory;

@end

@implementation AMAAutoPurchasesWatcher

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting>)executor
             transactionObserver:(AMATransactionObserver *)observer
                         factory:(AMARevenueInfoModelFactory *)factory
{
    self = [super init];
    if (self != nil) {
        _executor = executor;
        _observer = observer;
        _requesters = [NSMutableSet set];
        _factory = factory;
    }
    return self;
}

- (instancetype)initWithExecutor:(id<AMAAsyncExecuting>)executor
{
    return [self initWithExecutor:executor
              transactionObserver:[[AMATransactionObserver alloc] initWithDelegate:self]
                          factory:[[AMARevenueInfoModelFactory alloc] init]];
}

#pragma mark - Public -

- (void)startWatchingWithReporter:(AMAReporter *)reporter
{
    @synchronized (self) {
        AMALogInfo(@"reporter: %@", reporter);
        self.reporter = reporter;
        [self.observer startObservingTransactions];
    }
}

#pragma mark - Private -

- (void)handleProduct:(SKProduct *)product requestor:(AMAProductRequestor *)requestor
{
    @synchronized (self) {
        [self.requesters removeObject:requestor];
    }
    [self.executor execute:^{
        [self reportRevenueWithProduct:product requestor:requestor];
    }];
}

- (void)reportRevenueWithProduct:(SKProduct *)product requestor:(AMAProductRequestor *)requestor
{
    AMARevenueInfoModel *model = [self.factory revenueInfoModelWithTransaction:requestor.transaction
                                                                         state:requestor.transactionState
                                                                       product:product];
    [self.reporter reportAutoRevenue:model onFailure:nil];
}


#pragma mark - AMATransactionObserverDelegate

- (void)transactionObserver:(AMATransactionObserver *)observer
      didCaptureTransaction:(SKPaymentTransaction *)transaction
                  withState:(AMATransactionState)state
{
    AMAProductRequestor *requestor = [[AMAProductRequestor alloc] initWithTransaction:transaction
                                                                     transactionState:state
                                                                             delegate:self];
    @synchronized (self) {
        [self.requesters addObject:requestor];
    }
    [requestor requestProductInformation];
}

#pragma mark - AMAProductRequestorDelegate

- (void)productRequestor:(AMAProductRequestor *)requestor didRecieveProduct:(SKProduct *)product
{
    AMALogInfo(@"Received product:%@ for transaction:%@", product.productIdentifier,
                       requestor.transaction.transactionIdentifier);
    [self handleProduct:product requestor:requestor];
}

- (void)productRequestorDidFailToFetchProduct:(AMAProductRequestor *)requestor
{
    AMALogInfo(@"No product was fetched. Continuing reporting transaction:%@",
                       requestor.transaction.transactionIdentifier);
    [self handleProduct:nil requestor:requestor];
}

@end
