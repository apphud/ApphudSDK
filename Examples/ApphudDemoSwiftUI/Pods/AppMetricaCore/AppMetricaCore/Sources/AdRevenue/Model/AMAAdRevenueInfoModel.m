
#import "AMAAdRevenueInfoModel.h"

@interface AMAAdRevenueInfoModel ()

@property (nonatomic, strong) NSDecimalNumber *amount;
@property (nonatomic, copy) NSString *currency;
@property (nonatomic, assign) AMAAdType adType;
@property (nonatomic, copy) NSString *adNetwork;
@property (nonatomic, copy) NSString *adUnitID;
@property (nonatomic, copy) NSString *adUnitName;
@property (nonatomic, copy) NSString *adPlacementID;
@property (nonatomic, copy) NSString *adPlacementName;
@property (nonatomic, copy) NSString *precision;
@property (nonatomic, copy) NSString *payloadString;
@property (nonatomic, assign) NSUInteger bytesTruncated;

@end

@implementation AMAAdRevenueInfoModel

- (instancetype)initWithAmount:(NSDecimalNumber *)amount
                      currency:(NSString *)currency
                        adType:(AMAAdType)adType
                     adNetwork:(NSString *)adNetwork
                      adUnitID:(NSString *)adUnitID
                    adUnitName:(NSString *)adUnitName
                 adPlacementID:(NSString *)adPlacementID
               adPlacementName:(NSString *)adPlacementName
                     precision:(NSString *)precision
                 payloadString:(NSString *)payloadString
                bytesTruncated:(NSUInteger)bytesTruncated
{
    self = [super init];
    if (self != nil) {
        _amount = amount;
        _currency = [currency copy];
        _adType = adType;
        _adNetwork = [adNetwork copy];
        _adUnitID = [adUnitID copy];
        _adUnitName = [adUnitName copy];
        _adPlacementID = [adPlacementID copy];
        _adPlacementName = [adPlacementName copy];
        _precision = [precision copy];
        _payloadString = [payloadString copy];
        _bytesTruncated = bytesTruncated;
    }

    return self;
}

@end
