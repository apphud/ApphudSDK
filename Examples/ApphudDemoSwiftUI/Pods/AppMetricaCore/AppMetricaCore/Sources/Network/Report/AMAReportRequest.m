
#import "AMACore.h"
#import "AMAEvent.h"
#import "AMAReportRequest.h"
#import "AMAReportPayload.h"
#import "AMAReportRequestModel.h"

@class AMAReportEventsBatch;

@implementation AMAReportRequest

+ (instancetype)reportRequestWithPayload:(AMAReportPayload *)reportPayload
                       requestIdentifier:(NSString *)requestIdentifier
                requestParametersOptions:(AMARequestParametersOptions)requestParametersOptions
{
    return [[AMAReportRequest alloc] initWithPayload:reportPayload
                                   requestIdentifier:requestIdentifier
                            requestParametersOptions:requestParametersOptions];
}

- (instancetype)initWithPayload:(AMAReportPayload *)reportPayload
              requestIdentifier:(NSString *)requestIdentifier
       requestParametersOptions:(AMARequestParametersOptions)requestParametersOptions
{
    self = [super init];
    if (self != nil) {
        _reportPayload = reportPayload;
        _requestIdentifier = [requestIdentifier copy];
        _requestParametersOptions = requestParametersOptions;
    }
    return self;
}

- (NSDictionary *)headerComponents
{
    NSMutableDictionary *headers = [super headerComponents].mutableCopy;
    [AMANetworkingUtilities addUserAgentHeadersToDictionary:headers];
    AMADateProvider *dateProvider = [[AMADateProvider alloc] init];
    [AMANetworkingUtilities addSendTimeHeadersToDictionary:headers date:dateProvider.currentDate];
    return headers.copy;
}

- (NSMutableArray *)pathComponents
{
    NSMutableArray *pathComponents = [super pathComponents].mutableCopy;
    [pathComponents addObject:@"report"];
    return pathComponents;
}

- (NSDictionary *)GETParameters
{
    AMARequestParameters *requestParameters =
            [[AMARequestParameters alloc] initWithApiKey:self.reportPayload.model.apiKey
                                           attributionID:self.reportPayload.model.attributionID
                                               requestID:self.requestIdentifier
                                        applicationState:self.reportPayload.model.appState
                                        inMemoryDatabase:self.reportPayload.model.inMemoryDatabase
                                                 options:self.requestParametersOptions];
    return [[requestParameters dictionaryRepresentation] mutableCopy];
}

- (NSData *)body
{
    return self.reportPayload.data;
}

- (NSURLRequest *)buildURLRequest
{
    NSURLRequest *request = nil;
    if (self.reportPayload.data != nil) {
        request = [super buildURLRequest];
        AMALogInfo(@"Report request(size: %lu): %@", (unsigned long)self.reportPayload.data.length, request);
    }
    return [request copy];
}

@end
