
#import "AMACore.h"
#import "AMAAdRevenueInfoConverter.h"
#import "AMAAdRevenueInfoModel.h"
#import "AMAAdRevenueInfo.h"

@implementation AMAAdRevenueInfoConverter

+ (AMAAdRevenueInfoModel *)convertAdRevenueInfo:(AMAAdRevenueInfo *)adRevenueInfo
                                          error:(NSError **)error
{
    NSString *payloadString = [AMAJSONSerialization stringWithJSONObject:adRevenueInfo.payload error:error];
    AMAAdRevenueInfoModel *model = [[AMAAdRevenueInfoModel alloc] initWithAmount:adRevenueInfo.adRevenue
                                                                        currency:adRevenueInfo.currency
                                                                          adType:adRevenueInfo.adType
                                                                       adNetwork:adRevenueInfo.adNetwork
                                                                        adUnitID:adRevenueInfo.adUnitID
                                                                      adUnitName:adRevenueInfo.adUnitName
                                                                   adPlacementID:adRevenueInfo.adPlacementID
                                                                 adPlacementName:adRevenueInfo.adPlacementName
                                                                       precision:adRevenueInfo.precision
                                                                   payloadString:payloadString
                                                                  bytesTruncated:0];
    return model;
}

@end
