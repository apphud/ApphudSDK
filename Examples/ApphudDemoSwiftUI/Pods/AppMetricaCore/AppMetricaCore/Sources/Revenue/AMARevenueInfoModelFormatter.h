
#import <Foundation/Foundation.h>

@class AMARevenueInfoProcessingLogger;
@class AMARevenueInfoModel;
@class AMARevenueInfo;
@protocol AMAStringTruncating;

@interface AMARevenueInfoModelFormatter : NSObject

- (instancetype)initWithProductIDTruncator:(id<AMAStringTruncating>)productIDTruncator
                    transactionIDTruncator:(id<AMAStringTruncating>)transactionIDTruncator
                    payloadStringTruncator:(id<AMAStringTruncating>)payloadStringTruncator
                                    logger:(AMARevenueInfoProcessingLogger *)logger;

- (AMARevenueInfoModel *)formattedRevenueModel:(AMARevenueInfoModel *)revenueModel error:(NSError **)error;

@end
