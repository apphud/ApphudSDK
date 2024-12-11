
#import "AMAStartupResponse.h"

@class AMAAttributionModelParser;

@interface AMAStartupResponseParser : NSObject

- (instancetype)initWithAttributionModelParser:(AMAAttributionModelParser *)attributionModelParser;
- (AMAStartupResponse *)startupResponseWithHTTPResponse:(NSHTTPURLResponse *)HTTPResponse
                                                   data:(NSData *)data
                                                  error:(NSError **)error;
- (NSDictionary *)extendedStartupResponseWithHTTPResponse:(NSHTTPURLResponse *)HTTPResponse
                                                     data:(NSData *)data
                                                    error:(NSError **)error;

@end
