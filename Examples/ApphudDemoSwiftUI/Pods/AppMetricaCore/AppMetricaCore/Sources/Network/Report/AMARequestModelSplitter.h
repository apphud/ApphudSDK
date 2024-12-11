
#import <Foundation/Foundation.h>

@class AMAReportRequestModel;

NS_ASSUME_NONNULL_BEGIN

@interface AMARequestModelSplitter : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

+ (NSArray<AMAReportRequestModel *> *)splitRequestModel:(AMAReportRequestModel *)requestModel
                                                inParts:(NSUInteger)numberOfParts;

+ (AMAReportRequestModel *)extractTrackingRequestModelFromModel:(AMAReportRequestModel * _Nonnull __autoreleasing * _Nonnull)requestModel;

@end

NS_ASSUME_NONNULL_END

