
#import <Foundation/Foundation.h>

@class AMAAdRevenueInfoModel;

@interface AMAAdRevenueInfoModelSerializer : NSObject

- (NSData *)dataWithAdRevenueInfoModel:(AMAAdRevenueInfoModel *)model;

@end
