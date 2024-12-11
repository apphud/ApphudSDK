
#import <AppMetricaNetwork/AppMetricaNetwork.h>

@interface AMAStartupRequest : AMAGenericRequest

- (void)addAdditionalStartupParameters:(NSDictionary *)parameters;

@end
