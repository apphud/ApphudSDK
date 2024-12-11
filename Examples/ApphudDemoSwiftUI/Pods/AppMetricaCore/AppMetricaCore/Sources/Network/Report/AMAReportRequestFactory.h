
#import <Foundation/Foundation.h>

@class AMAReportRequest;
@class AMAReportPayload;

NS_ASSUME_NONNULL_BEGIN

NS_SWIFT_NAME(ReportRequestFactory)
@protocol AMAReportRequestFactory<NSObject>
- (AMAReportRequest *)reportRequestWithPayload:(AMAReportPayload *)reportPayload
                             requestIdentifier:(NSString *)requestIdentifier;
@end

NS_SWIFT_NAME(RegularReportRequestFactory)
@interface AMARegularReportRequestFactory : NSObject<AMAReportRequestFactory>
@end

NS_SWIFT_NAME(TrackingReportRequestFactory)
@interface AMATrackingReportRequestFactory : NSObject<AMAReportRequestFactory>
@end


NS_ASSUME_NONNULL_END
