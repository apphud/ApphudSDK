
#import "AMANetworkCore.h"
#import <AppMetricaNetwork/AppMetricaNetwork.h>

static NSURLRequestCachePolicy const kAMARequestCachePolicy = NSURLRequestReloadIgnoringCacheData;
static NSTimeInterval const kAMARequestTimeout = 60.0;

@implementation AMAGenericRequest

#pragma mark - Public -

@synthesize host;

- (NSString *)method
{
    return @"POST";
}

- (NSData *)body
{
    return nil;
}

- (NSDictionary *)headerComponents
{
    return @{};
}

- (NSArray *)pathComponents
{
    NSMutableArray *components = [NSMutableArray array];
    return components;
}

- (NSMutableDictionary *)GETParameters
{
    NSMutableDictionary *params = [NSMutableDictionary dictionary];
    return params;
}

- (NSTimeInterval)timeout
{
    return kAMARequestTimeout;
}

- (NSURLRequestCachePolicy)cachePolicy
{
    return kAMARequestCachePolicy;
}

- (NSURL *)url
{
    if (self.host == nil) {
        return nil;
    }
    return [AMAURLUtilities URLWithBaseURLString:self.host
                                  pathComponents:[[self pathComponents] copy]
                               httpGetParameters:[[self GETParameters] copy]];
}


- (NSURLRequest *)buildURLRequest
{
    NSURL *url = [self url];

    if (url == nil) {
        return nil;
    }
    NSMutableURLRequest *request = [[NSMutableURLRequest alloc] initWithURL:url
                                                                cachePolicy:[self cachePolicy]
                                                            timeoutInterval:[self timeout]];

    NSDictionary *httpHeaders = [self headerComponents];
    if ([httpHeaders count] > 0) {
        [request setAllHTTPHeaderFields:httpHeaders];
    }
    NSString *httpMethod = [self method];
    if (httpMethod != nil) {
        [request setHTTPMethod:httpMethod];
    }
    NSData *httpBody = [self body];
    if (httpBody != nil) {
        [request setHTTPBody:httpBody];
    }

    return [request copy];
}

@end
