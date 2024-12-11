
#import "AMACore.h"
#import "AMALightRevenueEventConverter.h"
#import "AMARevenueInfoModel.h"
#import "AMALightRevenueEvent.h"
#import "AMATransactionInfoModel.h"
#import "Revenue.pb-c.h"
#import "AMARevenueInfoModelSerializer.h"
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>

@interface AMALightRevenueEventConverter ()

@property (nonatomic, strong, readonly) AMARevenueInfoModelSerializer *serializer;

@end

@implementation AMALightRevenueEventConverter

- (instancetype)init
{
    self = [super init];
    if (self != nil) {
        _serializer = [[AMARevenueInfoModelSerializer alloc] init];
    }
    return self;
}

- (AMALightRevenueEvent *)eventFromModel:(AMARevenueInfoModel *)model
{
    NSDecimalNumber *priceMicros = model.priceDecimal;
    priceMicros = [AMADecimalUtils decimalNumber:priceMicros
                           bySafelyMultiplyingBy:[[NSDecimalNumber alloc] initWithInt:1000000]
                                              or:[NSDecimalNumber zero]];
    BOOL isRestore = model.transactionInfo.transactionState == AMATransactionStateRestored;
    return [[AMALightRevenueEvent alloc] initWithPriceMicros:priceMicros
                                                    currency:model.currency
                                                    quantity:model.quantity
                                               transactionID:model.transactionID
                                                      isAuto:model.isAutoCollected
                                                   isRestore:isRestore];
}

- (AMALightRevenueEvent *)eventFromSerializedValue:(id)value
{
    NS_VALID_UNTIL_END_OF_SCOPE AMAProtobufAllocator *allocator = [[AMAProtobufAllocator alloc] init];
    Ama__Revenue *revenueData = [self.serializer deserializeRevenue:value allocator:allocator];
    if (revenueData == NULL) {
        AMALogWarn(@"Could not deserialize revenue event");
        return nil;
    }
    BOOL isRestore = NO;
    if (revenueData->transaction_info != NULL) {
        isRestore = revenueData->transaction_info->state == AMA__REVENUE__TRANSACTION__STATE__RESTORED;
    }
    NSString *transactionID = nil;
    if (revenueData->receipt != NULL) {
        transactionID = [AMAProtobufUtilities stringForBinaryData:&revenueData->receipt->transaction_id];
    }
    BOOL isAuto = [AMAProtobufUtilities boolForProto:revenueData->auto_collected];
    NSDecimalNumber *priceMicros;
    if (revenueData->has_price_micros) {
        priceMicros = [[NSDecimalNumber alloc] initWithLongLong:revenueData->price_micros];
    }
    else {
        priceMicros = [NSDecimalNumber zero];
    }
    NSString *currency = [AMAProtobufUtilities stringForBinaryData:&revenueData->currency];
    return [[AMALightRevenueEvent alloc] initWithPriceMicros:priceMicros
                                                    currency:currency
                                                    quantity:revenueData->quantity
                                               transactionID:transactionID
                                                      isAuto:isAuto
                                                   isRestore:isRestore];
}

@end
