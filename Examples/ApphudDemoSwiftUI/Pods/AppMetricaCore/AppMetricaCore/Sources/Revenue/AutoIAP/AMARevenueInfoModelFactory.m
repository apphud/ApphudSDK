
#import "AMACore.h"
#import "AMARevenueInfoModelFactory.h"
#import <StoreKit/StoreKit.h>
#import "AMASubscriptionPeriod.h"
#import "AMATransactionInfoModel.h"
#import "AMASubscriptionInfoModel.h"
#import "AMARevenueInfoModel.h"
#import "AMAMetricaDynamicFrameworks.h"

@interface AMARevenueInfoModelFactory ()

@property (nonatomic, strong, readonly) AMAFramework *storeKit;

@end

@implementation AMARevenueInfoModelFactory

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _storeKit = AMAMetricaDynamicFrameworks.storeKit;
    }
    return self;
}

- (AMARevenueInfoModel *)revenueInfoModelWithTransaction:(SKPaymentTransaction *)transaction
                                                   state:(AMATransactionState)state
                                                 product:(SKProduct *)product
{
    NSString *transactionID = nil;
    NSDate *transactionDate = nil;

    NSString *secondaryID = nil;
    NSDate *secondaryDate = nil;

    switch (state) {
        case AMATransactionStatePurchased:
            transactionID = transaction.transactionIdentifier;
            transactionDate = transaction.transactionDate;

            secondaryID = transaction.originalTransaction.transactionIdentifier;
            secondaryDate = transaction.originalTransaction.transactionDate;
            break;
        case AMATransactionStateRestored:
            transactionID = transaction.originalTransaction.transactionIdentifier;
            transactionDate = transaction.originalTransaction.transactionDate;

            secondaryID = transaction.transactionIdentifier;
            secondaryDate = transaction.transactionDate;
            break;
        case AMATransactionStateUndefined:
        default:
            AMALogAssert(@"Undefined transaction state:%tu", state);
            break;
    }

    AMATransactionInfoModel *transactionModel = [[AMATransactionInfoModel alloc] initWithTransactionID:transactionID
                                                                                       transactionTime:transactionDate
                                                                                      transactionState:state
                                                                                           secondaryID:secondaryID
                                                                                         secondaryTime:secondaryDate];

    BOOL isSubscription = [self isSubscription:product];
    AMASubscriptionInfoModel *subscriptionModel = nil;
    if (isSubscription) {
        subscriptionModel = [self constructSubscriptionModelWithProduct:product];
    }

    AMARevenueInfoModel *revenueInfoModel =
    [[AMARevenueInfoModel alloc] initWithPriceDecimal:product.price
                                             currency:[product.priceLocale objectForKey:NSLocaleCurrencyCode]
                                             quantity:(NSUInteger)transaction.payment.quantity
                                            productID:transaction.payment.productIdentifier
                                        transactionID:transactionID
                                          receiptData:[self getReceiptData]
                                        payloadString:nil
                                       bytesTruncated:0
                                      isAutoCollected:YES
                                            inAppType:isSubscription ? AMAInAppTypeSubscription : AMAInAppTypePurchase
                                     subscriptionInfo:subscriptionModel
                                      transactionInfo:transactionModel
    ];
    return revenueInfoModel;
}

- (NSData *)getReceiptData
{
    NSURL *receiptURL = [[NSBundle mainBundle] appStoreReceiptURL];
    NSData *receiptData = nil;
    if (receiptURL != nil) {
        receiptData = [NSData dataWithContentsOfURL:receiptURL];
    }
    return receiptData;
}

#pragma mark - Subscription
#pragma clang diagnostic push
#pragma ide diagnostic ignored "UnavailableInDeploymentTarget"
- (AMASubscriptionInfoModel *)constructSubscriptionModelWithProduct:(SKProduct *)product
{
    AMASubscriptionInfoModel *model = nil;
    if (@available(iOS 11.2, tvOS 11.2, *)) {
        NSString *introductoryID = nil;
        if (@available(iOS 12.2, tvOS 12.2, *)) {
            introductoryID = product.introductoryPrice.identifier;
        }

        SKProductDiscount *discount = product.introductoryPrice;
        AMASubscriptionPeriod *introductoryPeriod = [self convertSubscriptionPeriod:discount.subscriptionPeriod];

        model = [[AMASubscriptionInfoModel alloc] initWithIsAutoRenewing:YES
                                                      subscriptionPeriod:[self convertSubscriptionPeriod:product.subscriptionPeriod]
                                                          introductoryID:introductoryID
                                                       introductoryPrice:product.introductoryPrice.price
                                                      introductoryPeriod:introductoryPeriod
                                                 introductoryPeriodCount:discount.numberOfPeriods];
    }
    return model;
}

- (BOOL)isSubscription:(SKProduct *)product
{
    if (@available(iOS 11.2, tvOS 11.2, *)) {
        return product.subscriptionPeriod != nil && product.subscriptionPeriod.numberOfUnits > 0;
    }
    return NO;
}

- (AMASubscriptionPeriod *)convertSubscriptionPeriod:(id)object
{
    if (@available(iOS 11.2, tvOS 11.2, *)) {
        if ([object isKindOfClass:[self.storeKit classFromString:@"SKProductSubscriptionPeriod"]]) {
            SKProductSubscriptionPeriod *period = (SKProductSubscriptionPeriod *)object;

            AMATimeUnit timeUnit = AMATimeUnitUndefined;
            switch (period.unit) {
                case SKProductPeriodUnitDay:
                    timeUnit = AMATimeUnitDay;
                    break;
                case SKProductPeriodUnitWeek:
                    timeUnit = AMATimeUnitWeek;
                    break;
                case SKProductPeriodUnitMonth:
                    timeUnit = AMATimeUnitMonth;
                    break;
                case SKProductPeriodUnitYear:
                    timeUnit = AMATimeUnitYear;
                    break;
                default:
                    break;
            }

            return [[AMASubscriptionPeriod alloc] initWithCount:period.numberOfUnits
                                                       timeUnit:timeUnit];
        }
    }
    return nil;
}

#pragma clang diagnostic pop

@end
