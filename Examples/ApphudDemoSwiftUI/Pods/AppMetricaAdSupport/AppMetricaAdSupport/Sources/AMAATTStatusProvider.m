
#import "AMAATTStatusProvider.h"
#import <AppTrackingTransparency/AppTrackingTransparency.h>
#import <AdSupport/AdSupport.h>

@implementation AMAATTStatusProvider

#pragma mark - Public -

- (BOOL)isAdvertisingTrackingEnabled
{
    if (@available(iOS 14, tvOS 14, *)) {
        return [self isAppTrackingAvailable];
    }
    else {
        return [[ASIdentifierManager sharedManager] isAdvertisingTrackingEnabled];
    }
}

- (AMATrackingManagerAuthorizationStatus)ATTStatus
{
    return (AMATrackingManagerAuthorizationStatus)[ATTrackingManager trackingAuthorizationStatus];
}

#pragma mark - Private -

- (BOOL)isAppTrackingAvailable API_AVAILABLE(ios(14.0), tvos(14.0))
{
    return [self ATTStatus] == AMATrackingManagerAuthorizationStatusAuthorized;
}

@end
