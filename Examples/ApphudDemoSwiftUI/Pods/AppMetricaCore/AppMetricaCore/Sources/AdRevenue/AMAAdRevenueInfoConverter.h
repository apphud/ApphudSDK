
#import <Foundation/Foundation.h>

@class AMAAdRevenueInfoModel;
@class AMAAdRevenueInfo;

@interface AMAAdRevenueInfoConverter : NSObject

+ (AMAAdRevenueInfoModel *)convertAdRevenueInfo:(AMAAdRevenueInfo *)adRevenueInfo
                                          error:(NSError **)error;

@end
