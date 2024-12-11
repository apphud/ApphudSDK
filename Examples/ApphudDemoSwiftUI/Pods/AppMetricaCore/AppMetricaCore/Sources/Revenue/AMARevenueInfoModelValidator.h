
#import <Foundation/Foundation.h>

@class AMARevenueInfoProcessingLogger;
@class AMARevenueInfoModel;

@interface AMARevenueInfoModelValidator : NSObject

- (instancetype)initWithLogger:(AMARevenueInfoProcessingLogger *)logger;

- (BOOL)validateRevenueInfoModel:(AMARevenueInfoModel *)model error:(NSError **)error;

@end
