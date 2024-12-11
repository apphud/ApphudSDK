
#import "AMACore.h"
#import "AMAAdRevenueInfoModelSerializer.h"
#import "AdRevenue.pb-c.h"
#import "AMAAdRevenueInfoModel.h"
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>

@implementation AMAAdRevenueInfoModelSerializer

#pragma mark - Public -

- (NSData *)dataWithAdRevenueInfoModel:(AMAAdRevenueInfoModel *)model
{
    NSData *__block packedAdRevenue = nil;
    [AMAAllocationsTrackerProvider track:^(id<AMAAllocationsTracking> tracker) {
        Ama__AdRevenue adRevenue = AMA__AD_REVENUE__INIT;

        adRevenue.ad_revenue = [self serializeDecimal:model.amount tracker:tracker];

        adRevenue.has_ad_type = true;
        adRevenue.ad_type = [self protoStateForState:model.adType];

        adRevenue.has_currency = [AMAProtobufUtilities fillBinaryData:&(adRevenue.currency)
                                                           withString:model.currency
                                                              tracker:tracker];
        adRevenue.has_ad_network = [AMAProtobufUtilities fillBinaryData:&(adRevenue.ad_network)
                                                             withString:model.adNetwork
                                                                tracker:tracker];
        adRevenue.has_ad_unit_id = [AMAProtobufUtilities fillBinaryData:&(adRevenue.ad_unit_id)
                                                             withString:model.adUnitID
                                                                tracker:tracker];
        adRevenue.has_ad_unit_name = [AMAProtobufUtilities fillBinaryData:&(adRevenue.ad_unit_name)
                                                               withString:model.adUnitName
                                                                  tracker:tracker];
        adRevenue.has_ad_placement_id = [AMAProtobufUtilities fillBinaryData:&(adRevenue.ad_placement_id)
                                                                  withString:model.adPlacementID
                                                                     tracker:tracker];
        adRevenue.has_ad_placement_name = [AMAProtobufUtilities fillBinaryData:&(adRevenue.ad_placement_name)
                                                                    withString:model.adPlacementName
                                                                       tracker:tracker];
        adRevenue.has_precision = [AMAProtobufUtilities fillBinaryData:&(adRevenue.precision)
                                                            withString:model.precision
                                                               tracker:tracker];
        adRevenue.has_payload = [AMAProtobufUtilities fillBinaryData:&(adRevenue.payload)
                                                          withString:model.payloadString
                                                             tracker:tracker];

        packedAdRevenue = [self packAdRevenue:&adRevenue];
    }];

    return packedAdRevenue;
}

#pragma mark - Private -

- (NSData *)packAdRevenue:(Ama__AdRevenue *)adRevenue
{
    size_t dataSize = ama__ad_revenue__get_packed_size(adRevenue);
    void *buffer = malloc(dataSize);
    ama__ad_revenue__pack(adRevenue, buffer);
    NSData *data = [NSData dataWithBytesNoCopy:buffer length:dataSize];
    return data;
}

- (Ama__AdRevenue__AdType)protoStateForState:(AMAAdType)adType
{
    switch (adType) {
        case AMAAdTypeNative:
            return AMA__AD_REVENUE__AD_TYPE__NATIVE;
        case AMAAdTypeBanner:
            return AMA__AD_REVENUE__AD_TYPE__BANNER;
        case AMAAdTypeRewarded:
            return AMA__AD_REVENUE__AD_TYPE__REWARDED;
        case AMAAdTypeInterstitial:
            return AMA__AD_REVENUE__AD_TYPE__INTERSTITIAL;
        case AMAAdTypeMrec:
            return AMA__AD_REVENUE__AD_TYPE__MREC;
        case AMAAdTypeOther:
            return AMA__AD_REVENUE__AD_TYPE__OTHER;
        case AMAAdTypeUnknown:
        default:
            return AMA__AD_REVENUE__AD_TYPE__UNKNOWN;
    }
}

- (Ama__AdRevenue__Decimal *)serializeDecimal:(NSDecimalNumber *)decimal
                                      tracker:(id<AMAAllocationsTracking>)tracker
{
    if (decimal == nil) {
        return NULL;
    }

    Ama__AdRevenue__Decimal *result = [tracker allocateSize:sizeof(Ama__AdRevenue__Decimal)];
    ama__ad_revenue__decimal__init(result);

    BOOL filled = [AMADecimalUtils fillMantissa:&result->mantissa exponent:&result->exponent withDecimal:decimal];
    result->has_exponent = filled;
    result->has_mantissa = filled;

    return result;
}

@end
