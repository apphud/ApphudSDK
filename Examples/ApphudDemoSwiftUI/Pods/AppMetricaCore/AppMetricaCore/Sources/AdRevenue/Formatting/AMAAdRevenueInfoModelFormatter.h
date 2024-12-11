
#import <Foundation/Foundation.h>

@class AMAAdRevenueInfoProcessingLogger;
@class AMAAdRevenueInfoModel;
@class AMAAdRevenueInfo;
@protocol AMAStringTruncating;

@interface AMAAdRevenueInfoModelFormatter : NSObject

- (instancetype)initWithStringTruncator:(id<AMAStringTruncating>)stringTruncator
                       payloadTruncator:(id<AMAStringTruncating>)payloadTruncator
                                 logger:(AMAAdRevenueInfoProcessingLogger *)logger;

- (AMAAdRevenueInfoModel *)formattedAdRevenueModel:(AMAAdRevenueInfoModel *)adRevenueModel;

@end
