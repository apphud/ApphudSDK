
#import "AMACore.h"
#import "AMAProductRequestor.h"
#import "AMAMetricaDynamicFrameworks.h"

@interface AMAProductRequestor ()

@property (nonatomic, strong, readonly) AMAFramework *storeKit;

@end

@implementation AMAProductRequestor

- (instancetype)initWithTransaction:(SKPaymentTransaction *)transaction
                   transactionState:(AMATransactionState)state
                           delegate:(id<AMAProductRequestorDelegate>)delegate
{
    self = [super init];
    if (self != nil) {
        _transaction = transaction;
        _storeKit = AMAMetricaDynamicFrameworks.storeKit;
        _transactionState = state;
        _delegate = delegate;
    }
    return self;
}

- (instancetype)init
{
    return [self initWithTransaction:nil transactionState:AMATransactionStateUndefined delegate:nil];
}

#pragma mark - Public -

- (void)requestProductInformation
{
    NSSet *productIdentifiers = [NSSet setWithObject:self.transaction.payment.productIdentifier];
    SKProductsRequest *productsRequest =
        [(SKProductsRequest *)[self.productRequest alloc] initWithProductIdentifiers:productIdentifiers];
    if (productsRequest != nil) {
        productsRequest.delegate = self;
        [productsRequest start];
    }
    else {
        AMALogWarn(@"StoreKit framework seems unavailable");
        [self.delegate productRequestorDidFailToFetchProduct:self];
    }
}

#pragma mark - Private -

- (Class)productRequest
{
    return [self.storeKit classFromString:@"SKProductsRequest"];
}

- (void)handleProduct:(SKProduct *)product
{
    if (product != nil) {
        [self.delegate productRequestor:self didRecieveProduct:product];
    }
    else {
        [self.delegate productRequestorDidFailToFetchProduct:self];
    }
}

#pragma mark - SKProductsRequestDelegate

- (void)productsRequest:(SKProductsRequest *)request didReceiveResponse:(SKProductsResponse *)response
{
    NSArray *products = response.products;
    NSArray *invalidProductIdentifiers = response.invalidProductIdentifiers;

    if (products.count + invalidProductIdentifiers.count != 1) {
        AMALogError(@"Expected one product per request. "
                            "Number of valid products:%tu. Invalids:%tu. ProductID:<%@>",
                            products.count,
                            invalidProductIdentifiers.count,
                            self.transaction.payment.productIdentifier);
        [self.delegate productRequestorDidFailToFetchProduct:self];
        return;
    }

    [self handleProduct:products.firstObject];
}

#pragma mark SKRequestDelegate

- (void)request:(SKRequest *)request didFailWithError:(NSError *)error
{
    AMALogError(@"Failed to fetch product information:%@ for transaction:%@. Error:%@",
                        request.debugDescription,
                        self.transaction.transactionIdentifier,
                        error);
    [self.delegate productRequestorDidFailToFetchProduct:self];
}


@end
