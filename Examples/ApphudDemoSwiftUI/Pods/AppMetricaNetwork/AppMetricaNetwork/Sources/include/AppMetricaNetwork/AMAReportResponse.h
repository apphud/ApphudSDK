
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

typedef NS_ENUM(NSInteger, AMAReportResponseStatus) {
    AMAReportResponseStatusUnknown,
    AMAReportResponseStatusAccepted,
} NS_SWIFT_NAME(ReportResponseStatus);

NS_SWIFT_NAME(ReportResponse)
@interface AMAReportResponse : NSObject

@property (nonatomic, assign, readonly) AMAReportResponseStatus status;

- (instancetype)initWithStatus:(AMAReportResponseStatus)status;

@end

NS_ASSUME_NONNULL_END
