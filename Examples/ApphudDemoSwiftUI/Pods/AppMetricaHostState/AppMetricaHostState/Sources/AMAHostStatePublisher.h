#import <AppMetricaCoreUtils/AppMetricaCoreUtils.h>

@interface AMAHostStatePublisher : NSObject <AMABroadcasting>

- (void)hostStateDidChange;

@end
