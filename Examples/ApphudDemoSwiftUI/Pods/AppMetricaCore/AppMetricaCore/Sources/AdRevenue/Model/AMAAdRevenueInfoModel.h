
#import <Foundation/Foundation.h>
#import "AMAAdRevenueInfo.h"

@interface AMAAdRevenueInfoModel : NSObject

@property (nonatomic, strong, readonly) NSDecimalNumber *amount;
@property (nonatomic, copy, readonly) NSString *currency;
@property (nonatomic, assign, readonly) AMAAdType adType;
@property (nonatomic, copy, readonly) NSString *adNetwork;
@property (nonatomic, copy, readonly) NSString *adUnitID;
@property (nonatomic, copy, readonly) NSString *adUnitName;
@property (nonatomic, copy, readonly) NSString *adPlacementID;
@property (nonatomic, copy, readonly) NSString *adPlacementName;
@property (nonatomic, copy, readonly) NSString *precision;
@property (nonatomic, copy, readonly) NSString *payloadString;
@property (nonatomic, assign, readonly) NSUInteger bytesTruncated;


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
                bytesTruncated:(NSUInteger)bytesTruncated;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end
