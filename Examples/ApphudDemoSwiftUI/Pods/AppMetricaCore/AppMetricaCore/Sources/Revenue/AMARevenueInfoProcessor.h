
#import <Foundation/Foundation.h>

@class AMARevenueInfo;
@class AMARevenueInfoModelFormatter;
@class AMARevenueInfoModelValidator;
@class AMARevenueInfoModelSerializer;
@class AMATruncatedDataProcessingResult;
@class AMARevenueInfoModel;

@interface AMARevenueInfoProcessor : NSObject

- (instancetype)initWithFormatter:(AMARevenueInfoModelFormatter *)formatter
                        validator:(AMARevenueInfoModelValidator *)validator
                       serializer:(AMARevenueInfoModelSerializer *)serializer;

- (AMATruncatedDataProcessingResult *)processRevenueModel:(AMARevenueInfoModel *)revenueModel error:(NSError **)error;

@end
