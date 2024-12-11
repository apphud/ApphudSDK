
#import "AMAReportPayload.h"

@implementation AMAReportPayload

- (instancetype)initWithReportModel:(AMAReportRequestModel *)model
                               data:(NSData *)data
{
    self = [super init];
    if (self != nil) {
        _model = model;
        _data = [data copy];
    }
    return self;
}

@end
