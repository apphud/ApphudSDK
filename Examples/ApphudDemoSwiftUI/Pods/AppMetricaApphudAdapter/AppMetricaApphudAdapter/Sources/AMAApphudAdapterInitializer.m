
#import "AMAApphudAdapterInitializer.h"
#import <AppMetricaCoreExtension/AppMetricaCoreExtension.h>
@import AppMetricaApphudObjCWrapper;

@implementation AMAApphudAdapterInitializer

+ (void)load
{
    [AMAAppMetrica registerExternalService:[AMAApphudManager shared].serviceConfiguration];
    [AMAAppMetrica addActivationDelegate:[AMAApphudManager class]];
}

@end
