
#import "AMAAppMetricaPreloadInfo+AMAInternal.h"

@implementation AMAAppMetricaPreloadInfo (AMASerialization)

- (NSDictionary *)preloadInfoJSONObject
{
    if (self.trackingID.length == 0) {
        return nil;
    }

    return @{
            @"preloadInfo" : @{
                    @"trackingId" : self.trackingID,
                    @"additionalParams" : self.additionalInfo ?: @{}
            }
    };
}

@end
