
#import <AppMetricaCoreExtension/AppMetricaCoreExtension.h>

@interface AMAATTStatusProvider : NSObject

- (BOOL)isAdvertisingTrackingEnabled;
- (AMATrackingManagerAuthorizationStatus)ATTStatus API_AVAILABLE(ios(14.0), tvos(14.0));

@end
