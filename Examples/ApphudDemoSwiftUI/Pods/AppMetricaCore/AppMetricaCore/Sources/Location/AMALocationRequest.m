
#import "AMALocationRequest.h"
#import "AMALocationRequestParameters.h"

@implementation AMALocationRequest

- (instancetype)initWithRequestIdentifier:(NSNumber *)requestIdentifier
                      locationIdentifiers:(NSArray<NSNumber *> *)locationIdentifiers
                         visitIdentifiers:(NSArray<NSNumber *> *)visitIdentifiers
                                     data:(NSData *)data
{
    self = [super init];
    if (self != nil) {
        _requestIdentifier = requestIdentifier;
        _locationIdentifiers = [locationIdentifiers copy];
        _visitIdentifiers = [visitIdentifiers copy];
        _data = [data copy];
    }
    return self;
}

- (NSDictionary *)headerComponents
{
    NSMutableDictionary *headers = [super headerComponents].mutableCopy;
    [AMANetworkingUtilities addUserAgentHeadersToDictionary:headers];
    return headers.copy;
}

- (NSDictionary *)GETParameters
{
    NSMutableDictionary *parameters = [[super GETParameters] mutableCopy];
    NSDictionary *requestParameters =
        [AMALocationRequestParameters parametersWithRequestIdentifier:self.requestIdentifier];
    [parameters addEntriesFromDictionary:requestParameters];
    return parameters;
}

- (NSMutableArray *)pathComponents
{
    NSMutableArray *pathComponents = [super pathComponents].mutableCopy;
    [pathComponents addObject:@"location"];
    return pathComponents;
}

- (NSData *)body
{
    return self.data;
}

- (NSURLRequest *)buildURLRequest
{
    NSURLRequest *request = nil;
    if (self.data != nil) {
        request = [super buildURLRequest];
    }
    return [request copy];
}

@end
