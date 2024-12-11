
#import "AMAAdRevenueInfo.h"

@interface AMAAdRevenueInfo ()

@property (nonatomic, assign, readwrite) AMAAdType adType;
@property (nonatomic, copy, readwrite, nullable) NSString *adNetwork;
@property (nonatomic, copy, readwrite, nullable) NSString *adUnitID;
@property (nonatomic, copy, readwrite, nullable) NSString *adUnitName;
@property (nonatomic, copy, readwrite, nullable) NSString *adPlacementID;
@property (nonatomic, copy, readwrite, nullable) NSString *adPlacementName;
@property (nonatomic, copy, readwrite, nullable) NSString *precision;
@property (nonatomic, copy, readwrite, nullable) NSDictionary<NSString *, NSString *> *payload;

- (instancetype)initWithAdRevenue:(NSDecimalNumber *)adRevenue
                         currency:(NSString *)currency
                           adType:(AMAAdType)adType
                        adNetwork:(nullable NSString *)adNetwork
                         adUnitID:(nullable NSString *)adUnitID
                       adUnitName:(nullable NSString *)adUnitName
                    adPlacementID:(nullable NSString *)adPlacementID
                  adPlacementName:(nullable NSString *)adPlacementName
                        precision:(nullable NSString *)precision
                          payload:(nullable NSDictionary<NSString *, NSString *> *)payload;

@end

@implementation AMAAdRevenueInfo

- (instancetype)initWithAdRevenue:(NSDecimalNumber *)adRevenue
                         currency:(NSString *)currency
{
    return [self initWithAdRevenue:adRevenue
                          currency:currency
                            adType:AMAAdTypeUnknown
                         adNetwork:nil
                          adUnitID:nil
                        adUnitName:nil
                     adPlacementID:nil
                   adPlacementName:nil
                         precision:nil
                           payload:nil];
}

- (instancetype)initWithAdRevenue:(NSDecimalNumber *)adRevenue
                         currency:(NSString *)currency
                           adType:(AMAAdType)adType
                        adNetwork:(nullable NSString *)adNetwork
                         adUnitID:(nullable NSString *)adUnitID
                       adUnitName:(nullable NSString *)adUnitName
                    adPlacementID:(nullable NSString *)adPlacementID
                  adPlacementName:(nullable NSString *)adPlacementName
                        precision:(nullable NSString *)precision
                          payload:(nullable NSDictionary<NSString *, NSString *> *)payload
{
    self = [super init];
    if (self != nil) {
        _adRevenue = adRevenue;
        _currency = [currency copy];
        _adType = adType;
        _adNetwork = [adNetwork copy];
        _adUnitID = [adUnitID copy];
        _adUnitName = [adUnitName copy];
        _adPlacementID = [adPlacementID copy];
        _adPlacementName = [adPlacementName copy];
        _precision = [precision copy];
        _payload = [payload copy];
    }
    return self;
}

- (id)copyWithZone:(nullable NSZone *)zone
{
    return self;
}

- (id)mutableCopyWithZone:(nullable NSZone *)zone
{
    return [[AMAMutableAdRevenueInfo alloc] initWithAdRevenue:self.adRevenue
                                                     currency:self.currency
                                                       adType:self.adType
                                                    adNetwork:self.adNetwork
                                                     adUnitID:self.adUnitID
                                                   adUnitName:self.adUnitName
                                                adPlacementID:self.adPlacementID
                                              adPlacementName:self.adPlacementName
                                                    precision:self.precision
                                                      payload:self.payload];
}

@end

@implementation AMAMutableAdRevenueInfo

@dynamic adRevenue;
@dynamic currency;
@dynamic adType;
@dynamic adNetwork;
@dynamic adUnitID;
@dynamic adUnitName;
@dynamic adPlacementID;
@dynamic adPlacementName;
@dynamic precision;
@dynamic payload;

- (id)copyWithZone:(nullable NSZone *)zone
{
    return [[AMAAdRevenueInfo alloc] initWithAdRevenue:self.adRevenue
                                              currency:self.currency
                                                adType:self.adType
                                             adNetwork:self.adNetwork
                                              adUnitID:self.adUnitID
                                            adUnitName:self.adUnitName
                                         adPlacementID:self.adPlacementID
                                       adPlacementName:self.adPlacementName
                                             precision:self.precision
                                               payload:self.payload];
}

@end
