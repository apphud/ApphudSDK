
#import "AMACore.h"
#import "AMARevenueInfoModelFormatter.h"
#import "AMARevenueInfoModel.h"
#import "AMARevenueInfoProcessingLogger.h"
#import "AMASubscriptionInfoModel.h"
#import "AMATransactionInfoModel.h"

static NSUInteger const kAMAProductIDLength = 200;
static NSUInteger const kAMATransactionIDLength = 200;
static NSUInteger const kAMAReceiptDataSize = 180 * 1024;
static NSUInteger const kAMAPayloadStringLength = 30 * 1024;

static NSString *const kAMATruncatedReceiptDataString = @"<truncated data was not sent, exceeded the limit of 180kb>";

@interface AMARevenueInfoModelFormatter ()

@property (nonatomic, strong, readonly) id<AMAStringTruncating> productIDTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> transactionIDTruncator;
@property (nonatomic, strong, readonly) id<AMAStringTruncating> payloadStringTruncator;
@property (nonatomic, strong, readonly) AMARevenueInfoProcessingLogger *logger;

@end

@implementation AMARevenueInfoModelFormatter

- (instancetype)init
{
    return [self initWithProductIDTruncator:[[AMABytesStringTruncator alloc] initWithMaxBytesLength:kAMAProductIDLength]
                     transactionIDTruncator:[[AMABytesStringTruncator alloc] initWithMaxBytesLength:kAMATransactionIDLength]
                     payloadStringTruncator:[[AMABytesStringTruncator alloc] initWithMaxBytesLength:kAMAPayloadStringLength]
                                     logger:[[AMARevenueInfoProcessingLogger alloc] init]];
}

- (instancetype)initWithProductIDTruncator:(id<AMAStringTruncating>)productIDTruncator
                    transactionIDTruncator:(id<AMAStringTruncating>)transactionIDTruncator
                    payloadStringTruncator:(id<AMAStringTruncating>)payloadStringTruncator
                                    logger:(AMARevenueInfoProcessingLogger *)logger
{
    self = [super init];
    if (self != nil) {
        _productIDTruncator = productIDTruncator;
        _transactionIDTruncator = transactionIDTruncator;
        _payloadStringTruncator = payloadStringTruncator;
        _logger = logger;
    }
    return self;
}

#pragma mark - Public -

- (AMARevenueInfoModel *)formattedRevenueModel:(AMARevenueInfoModel *)revenueModel error:(NSError **)error
{
    NSUInteger bytesTruncated = 0;
    NSString *truncatedProductID = [self truncatedProductID:revenueModel.productID bytesTruncated:&bytesTruncated];
    NSString *truncatedTransactionID = [self truncatedTransactionID:revenueModel.transactionID
                                                     bytesTruncated:&bytesTruncated];
    NSData *truncatedReceiptData = [self truncatedReceiptData:revenueModel.receiptData bytesTruncated:&bytesTruncated];
    NSString *truncatedPayloadString = [self truncatedPayloadString:revenueModel.payloadString
                                                     bytesTruncated:&bytesTruncated];
    AMASubscriptionInfoModel *truncatedSubscription = [self truncatedSubscription:revenueModel.subscriptionInfo
                                                                   bytesTruncated:&bytesTruncated];
    AMATransactionInfoModel *truncatedTransaction = [self truncatedTransaction:revenueModel.transactionInfo
                                                                bytesTruncated:&bytesTruncated];

    AMARevenueInfoModel *model = [[AMARevenueInfoModel alloc] initWithPriceDecimal:revenueModel.priceDecimal
                                                                          currency:revenueModel.currency
                                                                          quantity:revenueModel.quantity
                                                                         productID:truncatedProductID
                                                                     transactionID:truncatedTransactionID
                                                                       receiptData:truncatedReceiptData
                                                                     payloadString:truncatedPayloadString
                                                                    bytesTruncated:bytesTruncated
                                                                   isAutoCollected:revenueModel.isAutoCollected
                                                                         inAppType:revenueModel.inAppType
                                                                  subscriptionInfo:truncatedSubscription
                                                                   transactionInfo:truncatedTransaction];
    
    return model;
}

#pragma mark - Private -

- (AMASubscriptionInfoModel *)truncatedSubscription:(AMASubscriptionInfoModel *)model
                                     bytesTruncated:(NSUInteger *)bytesTruncated
{
    AMASubscriptionInfoModel *truncatedModel = nil;
    if (model != nil) {
        NSString *truncatedIntroductoryID = [self truncatedProductID:model.introductoryID bytesTruncated:bytesTruncated];

        truncatedModel = [[AMASubscriptionInfoModel alloc] initWithIsAutoRenewing:model.isAutoRenewing
                                                               subscriptionPeriod:model.subscriptionPeriod
                                                                   introductoryID:truncatedIntroductoryID
                                                                introductoryPrice:model.introductoryPrice
                                                               introductoryPeriod:model.introductoryPeriod
                                                          introductoryPeriodCount:model.introductoryPeriodCount];
    }
    return truncatedModel;
}

- (AMATransactionInfoModel *)truncatedTransaction:(AMATransactionInfoModel *)model
                                   bytesTruncated:(NSUInteger *)bytesTruncated
{
    AMATransactionInfoModel *truncatedModel = nil;
    if (model != nil) {
        NSString *truncatedTransactionID = [self truncatedTransactionID:model.transactionID bytesTruncated:bytesTruncated];
        NSString *truncatedSecondaryID = [self truncatedTransactionID:model.secondaryID bytesTruncated:bytesTruncated];

        truncatedModel = [[AMATransactionInfoModel alloc] initWithTransactionID:truncatedTransactionID
                                                                transactionTime:model.transactionTime
                                                               transactionState:model.transactionState
                                                                    secondaryID:truncatedSecondaryID
                                                                  secondaryTime:model.secondaryTime];
    }
    return truncatedModel;
}

- (NSString *)truncatedProductID:(NSString *)productID bytesTruncated:(NSUInteger *)bytesTruncated
{
    return [self.productIDTruncator truncatedString:productID onTruncation:^(NSUInteger length) {
        *bytesTruncated += length;
        [self.logger logTruncationOfType:@"productID" value:productID maxLength:kAMAProductIDLength];
    }];
}

- (NSString *)truncatedTransactionID:(NSString *)transactionID bytesTruncated:(NSUInteger *)bytesTruncated
{
    return [self.transactionIDTruncator truncatedString:transactionID onTruncation:^(NSUInteger length) {
        *bytesTruncated += length;
        [self.logger logTruncationOfType:@"transactionID" value:transactionID maxLength:kAMAProductIDLength];
    }];
}

- (NSData *)truncatedReceiptData:(NSData *)receiptData bytesTruncated:(NSUInteger *)bytesTruncated
{
    NSData *truncatedData = receiptData;
    if (receiptData.length > kAMAReceiptDataSize) {
        truncatedData = [kAMATruncatedReceiptDataString dataUsingEncoding:NSUTF8StringEncoding];
        *bytesTruncated += receiptData.length;
        [self.logger logTruncationOfReceiptDataWithLength:receiptData.length maxSize:kAMAReceiptDataSize];
    }
    return truncatedData;
}

- (NSString *)truncatedPayloadString:(NSString *)payloadString bytesTruncated:(NSUInteger *)bytesTruncated
{
    return [self.payloadStringTruncator truncatedString:payloadString onTruncation:^(NSUInteger length) {
        *bytesTruncated += length;
        [self.logger logTruncationOfPayloadString:payloadString maxLength:kAMAPayloadStringLength];
    }];
}

@end
