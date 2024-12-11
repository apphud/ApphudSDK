
#import "AMAReportRequestFactory.h"
#import "AMAReportRequest.h"

@implementation AMARegularReportRequestFactory

- (nonnull AMAReportRequest *)reportRequestWithPayload:(nonnull AMAReportPayload *)reportPayload
                                     requestIdentifier:(nonnull NSString *)requestIdentifier
{
    return [AMAReportRequest reportRequestWithPayload:reportPayload
                                    requestIdentifier:requestIdentifier
                             requestParametersOptions:AMARequestParametersDefault];
}

@end


@implementation AMATrackingReportRequestFactory

- (nonnull AMAReportRequest *)reportRequestWithPayload:(nonnull AMAReportPayload *)reportPayload
                                     requestIdentifier:(nonnull NSString *)requestIdentifier
{
    return [AMAReportRequest reportRequestWithPayload:reportPayload
                                    requestIdentifier:requestIdentifier
                             requestParametersOptions:AMARequestParametersTracking];
}

@end
