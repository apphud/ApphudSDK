
#import <Foundation/Foundation.h>

@class AMAReportRequestModel;

@interface AMAReportPayload : NSObject

@property (nonatomic, strong, readonly) AMAReportRequestModel *model;
@property (nonatomic, copy, readonly) NSData *data;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithReportModel:(AMAReportRequestModel *)model
                               data:(NSData *)data;

@end
