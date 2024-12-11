
#import "AppMetricaDefaultAnonymousConfigProvider.h"

NSString *const anonymousApiKey = @"629a824d-c717-4ba5-bc0f-3f3968554d01";

@implementation AppMetricaDefaultAnonymousConfigProvider

- (AMAAppMetricaConfiguration *)configuration
{
    return [[AMAAppMetricaConfiguration alloc] initWithAPIKey:anonymousApiKey];
}

@end
