
#import <Foundation/Foundation.h>
#import "AMAAppMetricaPreloadInfo.h"

@interface AMAAppMetricaPreloadInfo ()

@property (nonatomic, copy, readonly) NSString *trackingID;
@property (atomic, strong, readonly) NSDictionary *additionalInfo;

@end

@interface AMAAppMetricaPreloadInfo (AMASerialization)

- (NSDictionary *)preloadInfoJSONObject;

@end

