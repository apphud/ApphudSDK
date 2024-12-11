#import "AMAHostExchangeResponseValidating.h"

@class AMAReportResponse;

NS_SWIFT_NAME(ReportResponseParser)
@interface AMAReportResponseParser : NSObject <AMAHostExchangeResponseValidating>

- (AMAReportResponse *)responseForData:(NSData *)data;

@end
