
#import <Foundation/Foundation.h>

@class AMAAdRevenueInfoModelFormatter;
@class AMAAdRevenueInfoModelValidator;
@class AMAAdRevenueInfoModelSerializer;
@class AMATruncatedDataProcessingResult;
@class AMAAdRevenueInfoModel;

@interface AMAAdRevenueInfoProcessor : NSObject

- (instancetype)initWithFormatter:(AMAAdRevenueInfoModelFormatter *)formatter
                        validator:(AMAAdRevenueInfoModelValidator *)validator
                       serializer:(AMAAdRevenueInfoModelSerializer *)serializer;

- (AMATruncatedDataProcessingResult *)processAdRevenueModel:(AMAAdRevenueInfoModel *)adRevenueModel
                                                      error:(NSError **)error;

@end
