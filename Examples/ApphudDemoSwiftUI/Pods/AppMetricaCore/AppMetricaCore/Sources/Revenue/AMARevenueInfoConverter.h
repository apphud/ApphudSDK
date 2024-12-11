
#import <Foundation/Foundation.h>

@class AMARevenueInfoModel;
@class AMARevenueInfo;

@interface AMARevenueInfoConverter : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (AMARevenueInfoModel *)convertRevenueInfo:(AMARevenueInfo *)revenueInfo
                                      error:(NSError **)error;

@end
