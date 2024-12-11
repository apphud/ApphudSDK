
#import <AppMetricaNetwork/AppMetricaNetwork.h>

@implementation AMAReportResponse

- (instancetype)initWithStatus:(AMAReportResponseStatus)status
{
    self = [super init];
    if (self != nil) {
        _status = status;
    }
    return self;
}

@end
