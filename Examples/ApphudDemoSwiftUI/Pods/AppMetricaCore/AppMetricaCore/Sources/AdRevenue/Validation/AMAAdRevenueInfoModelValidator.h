
#import <Foundation/Foundation.h>

@class AMAAdRevenueInfoProcessingLogger;
@class AMAAdRevenueInfoModel;

@interface AMAAdRevenueInfoModelValidator : NSObject

- (instancetype)initWithLogger:(AMAAdRevenueInfoProcessingLogger *)logger;

- (BOOL)validateAdRevenueInfoModel:(AMAAdRevenueInfoModel *)model error:(NSError **)error;

@end
