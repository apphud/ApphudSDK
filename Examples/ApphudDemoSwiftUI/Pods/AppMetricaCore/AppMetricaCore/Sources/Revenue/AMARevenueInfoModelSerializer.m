
#import "AMACore.h"
#import "AMARevenueInfoModelSerializer.h"
#import "Revenue.pb-c.h"
#import "AMARevenueInfoModel.h"
#import "AMATransactionInfoModel.h"
#import "AMASubscriptionInfoModel.h"
#import "AMASubscriptionPeriod.h"
#import "AMABinaryEventValue.h"
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>

@implementation AMARevenueInfoModelSerializer

#pragma mark - Public -

- (NSData *)dataWithRevenueInfoModel:(AMARevenueInfoModel *)model
{
    NSData *__block packedRevenue = nil;
    [AMAAllocationsTrackerProvider track:^(id<AMAAllocationsTracking> tracker) {
        Ama__Revenue revenue = AMA__REVENUE__INIT;
        [AMAProtobufUtilities fillBinaryData:&(revenue.currency)
                                  withString:model.currency
                                     tracker:tracker];

        revenue.has_quantity = YES;
        revenue.quantity = (uint32_t)model.quantity;

        BOOL hasProductId = model.productID != nil;
        revenue.has_product_id = hasProductId;
        if (hasProductId) {
            [AMAProtobufUtilities fillBinaryData:&(revenue.product_id)
                                      withString:model.productID
                                         tracker:tracker];
        }

        BOOL hasPayload = model.payloadString != nil;
        revenue.has_payload = hasPayload;

        revenue.receipt = [self receiptForRevenueInfoModel:model tracker:tracker];
        BOOL hasDecimalPrice = model.priceDecimal != nil;

        revenue.has_price_micros = hasDecimalPrice;
        if (hasDecimalPrice) {
            revenue.has_price_micros = [AMADecimalUtils fillMicrosValue:&revenue.price_micros
                                                            withDecimal:model.priceDecimal];
        }

        revenue.has_auto_collected = true;
        revenue.auto_collected = model.isAutoCollected;
        revenue.has_in_app_type = true;
        revenue.in_app_type = [self protoInAppTypeForType:model.inAppType];

        revenue.transaction_info = [self protoTransactionWithModel:model.transactionInfo tracker:tracker];
        revenue.subscription_info = [self protoSubscriptionWithModel:model.subscriptionInfo tracker:tracker];

        if (hasPayload) {
            [AMAProtobufUtilities fillBinaryData:&(revenue.payload)
                                      withString:model.payloadString
                                         tracker:tracker];
        }
        packedRevenue = [self packRevenue:&revenue];
    }];

    return packedRevenue;
}

- (Ama__Revenue *)deserializeRevenue:(id)value allocator:(AMAProtobufAllocator *)allocator
{
    if ([value isKindOfClass:AMABinaryEventValue.class] == NO) {
        return NULL;
    }
    NSData *data = ((AMABinaryEventValue *) value).data;
    return ama__revenue__unpack(allocator.protobufCAllocator, data.length, data.bytes);
}

#pragma mark - Private -

- (NSData *)packRevenue:(Ama__Revenue *)revenue
{
    size_t dataSize = ama__revenue__get_packed_size(revenue);
    void *buffer = malloc(dataSize);
    ama__revenue__pack(revenue, buffer);
    NSData *data = [NSData dataWithBytesNoCopy:buffer length:dataSize];
    return data;
}

- (Ama__Revenue__Transaction *)protoTransactionWithModel:(AMATransactionInfoModel *)model
                                                 tracker:(id<AMAAllocationsTracking>)tracker
{
    Ama__Revenue__Transaction *transaction = NULL;
    if (model != nil) {
        transaction = [tracker allocateSize:sizeof(Ama__Revenue__Transaction)];
        ama__revenue__transaction__init(transaction);

        transaction->has_id = model.transactionID != nil;
        if (transaction->has_id) {
            [AMAProtobufUtilities fillBinaryData:&transaction->id withString:model.transactionID tracker:tracker];
        }

        transaction->has_time = model.transactionTime != nil;
        if (transaction->has_time) {
            transaction->time = (uint64_t)model.transactionTime.timeIntervalSince1970;
        }

        transaction->has_state = YES;
        transaction->state = [self protoStateForState:model.transactionState];

        transaction->has_secondary_id = model.secondaryID != nil;
        if (transaction->has_secondary_id) {
            [AMAProtobufUtilities fillBinaryData:&transaction->secondary_id
                                      withString:model.secondaryID
                                         tracker:tracker];
        }

        transaction->has_secondary_time = model.secondaryTime != nil;
        if (transaction->has_secondary_time) {
            transaction->secondary_time = (uint64_t)model.secondaryTime.timeIntervalSince1970;
        }
    }
    return transaction;
}

- (Ama__Revenue__SubscriptionInfo *)protoSubscriptionWithModel:(AMASubscriptionInfoModel *)model
                                                       tracker:(id<AMAAllocationsTracking>)tracker
{
    Ama__Revenue__SubscriptionInfo *subscriptionInfo = NULL;
    if (model != nil) {
        subscriptionInfo = [tracker allocateSize:sizeof(Ama__Revenue__SubscriptionInfo)];
        ama__revenue__subscription_info__init(subscriptionInfo);

        subscriptionInfo->has_auto_renewing = true;
        subscriptionInfo->auto_renewing = model.isAutoRenewing;

        subscriptionInfo->subscription_period = [self protoPeriodWithSubscriptionPeriod:model.subscriptionPeriod
                                                                                tracker:tracker];
        subscriptionInfo->introductory_info = [self protoIntroductoryInfoWithModel:model tracker:tracker];
    }
    return subscriptionInfo;
}

- (Ama__Revenue__SubscriptionInfo__Introductory *)protoIntroductoryInfoWithModel:(AMASubscriptionInfoModel *)model
                                                                         tracker:(id<AMAAllocationsTracking>)tracker
{
    Ama__Revenue__SubscriptionInfo__Introductory
        *introductory = [tracker allocateSize:sizeof(Ama__Revenue__SubscriptionInfo__Introductory)];
    ama__revenue__subscription_info__introductory__init(introductory);

    introductory->has_price_micros = model.introductoryPrice != nil;
    if (introductory->has_price_micros) {
        [AMADecimalUtils fillMicrosValue:&introductory->price_micros withDecimal:model.introductoryPrice];
    }

    introductory->period = [self protoPeriodWithSubscriptionPeriod:model.introductoryPeriod tracker:tracker];

    introductory->has_id = model.introductoryID != nil;
    if (introductory->has_id) {
        [AMAProtobufUtilities fillBinaryData:&introductory->id withString:model.introductoryID tracker:tracker];
    }

    introductory->has_number_of_periods = true;
    introductory->number_of_periods = (uint32_t)model.introductoryPeriodCount;

    return introductory;
}

- (Ama__Revenue__SubscriptionInfo__Period *)protoPeriodWithSubscriptionPeriod:(AMASubscriptionPeriod *)period
                                                                      tracker:(id<AMAAllocationsTracking>)tracker
{
    Ama__Revenue__SubscriptionInfo__Period *subscriptionPeriod = NULL;
    if (period != nil) {
        subscriptionPeriod = [tracker allocateSize:sizeof(Ama__Revenue__SubscriptionInfo__Period)];
        ama__revenue__subscription_info__period__init(subscriptionPeriod);

        subscriptionPeriod->has_number = true;
        subscriptionPeriod->number = (uint32_t)period.count;

        subscriptionPeriod->has_time_unit = true;
        subscriptionPeriod->time_unit = [self protoTimeUnitForUnit:period.timeUnit];
    }
    return subscriptionPeriod;
}

- (Ama__Revenue__Receipt *)receiptForRevenueInfoModel:(AMARevenueInfoModel *)model
                                              tracker:(id<AMAAllocationsTracking>)tracker
{
    if (model.transactionID == nil && model.receiptData == nil) {
        return NULL;
    }
    Ama__Revenue__Receipt *receipt = [tracker allocateSize:sizeof(Ama__Revenue__Receipt)];
    ama__revenue__receipt__init(receipt);

    BOOL hasTransactionID = model.transactionID != nil;
    receipt->has_transaction_id = hasTransactionID;
    if (hasTransactionID) {
        [AMAProtobufUtilities fillBinaryData:&(receipt->transaction_id)
                                  withString:model.transactionID
                                     tracker:tracker];
    }

    BOOL hasReceiptData = model.receiptData != nil;
    receipt->has_data = hasReceiptData;
    if (hasReceiptData) {
        [AMAProtobufUtilities fillBinaryData:&(receipt->data)
                                    withData:model.receiptData
                                     tracker:tracker];
    }
    return receipt;
}

- (Ama__Revenue__SubscriptionInfo__Period__TimeUnit)protoTimeUnitForUnit:(AMATimeUnit)unit
{
    switch (unit) {
        case AMATimeUnitDay:
            return AMA__REVENUE__SUBSCRIPTION_INFO__PERIOD__TIME_UNIT__DAY;
        case AMATimeUnitWeek:
            return AMA__REVENUE__SUBSCRIPTION_INFO__PERIOD__TIME_UNIT__WEEK;
        case AMATimeUnitMonth:
            return AMA__REVENUE__SUBSCRIPTION_INFO__PERIOD__TIME_UNIT__MONTH;
        case AMATimeUnitYear:
            return AMA__REVENUE__SUBSCRIPTION_INFO__PERIOD__TIME_UNIT__YEAR;
        case AMATimeUnitUndefined:
        default:
            return AMA__REVENUE__SUBSCRIPTION_INFO__PERIOD__TIME_UNIT__UNKNOWN;
    }
}

- (Ama__Revenue__Transaction__State)protoStateForState:(AMATransactionState)state
{
    switch (state) {
        case AMATransactionStatePurchased:
            return AMA__REVENUE__TRANSACTION__STATE__PURCHASED;
        case AMATransactionStateRestored:
            return AMA__REVENUE__TRANSACTION__STATE__RESTORED;
        case AMATransactionStateUndefined:
        default:
            return AMA__REVENUE__TRANSACTION__STATE__STATE_UNDEFINED;
    }
}

- (Ama__Revenue__InAppType)protoInAppTypeForType:(AMAInAppType)type
{
    switch (type) {
        case AMAInAppTypePurchase:
            return AMA__REVENUE__IN_APP_TYPE__PURCHASE;
        case AMAInAppTypeSubscription:
            return AMA__REVENUE__IN_APP_TYPE__SUBSCRIPTION;
        default:
            return AMA__REVENUE__IN_APP_TYPE__PURCHASE;
    }
}

@end
