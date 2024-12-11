
#import <AppMetricaNetwork/AppMetricaNetwork.h>

@implementation AMAReportResponseParser

- (AMAReportResponseStatus)statusForStatusName:(NSString *)statusName
{
    static NSDictionary *statuses = nil;
    static dispatch_once_t onceToken;
    dispatch_once(&onceToken, ^{
        statuses = @{
            @"accepted": @(AMAReportResponseStatusAccepted)
        };
    });

    NSNumber *statusNumber = nil;
    if (statusName != nil) {
        statusNumber = statuses[statusName];
    }
    AMAReportResponseStatus status = AMAReportResponseStatusUnknown;
    if (statusNumber != nil) {
        status = [statusNumber integerValue];
    }
    return status;
}

- (AMAReportResponse *)responseForData:(NSData *)data
{
    if (data.length == 0) {
        return nil;
    }

    AMAReportResponse *response = nil;
    NSDictionary *responseJSONObject = [NSJSONSerialization JSONObjectWithData:data options:0 error:NULL];
    if ([responseJSONObject isKindOfClass:[NSDictionary class]]) {
        NSString *statusName = responseJSONObject[@"status"];
        if (statusName != nil) {
            AMAReportResponseStatus status = [self statusForStatusName:statusName];
            response = [[AMAReportResponse alloc] initWithStatus:status];
        }
    }

    return response;
}

#pragma mark - AMAHostExchangeResponseValidating

- (BOOL)isResponseValidWithData:(NSData *)data
{
    AMAReportResponse *response = [self responseForData:data];
    return response != nil && response.status == AMAReportResponseStatusAccepted;
}

@end
