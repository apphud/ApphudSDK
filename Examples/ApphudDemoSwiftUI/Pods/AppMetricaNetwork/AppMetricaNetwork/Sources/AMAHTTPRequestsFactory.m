
#import "AMANetworkCore.h"
#import <AppMetricaNetwork/AppMetricaNetwork.h>

@implementation AMAHTTPRequestsFactory

- (AMAHTTPRequestor *)requestorForRequest:(id<AMARequest>)request
{
    return [AMAHTTPRequestor requestorWithRequest:request];
}

@end
