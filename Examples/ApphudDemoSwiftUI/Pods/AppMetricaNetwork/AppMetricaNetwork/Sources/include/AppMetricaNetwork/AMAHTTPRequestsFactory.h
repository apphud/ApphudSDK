
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AMAHTTPRequestor;
@protocol AMARequest;

NS_SWIFT_NAME(HTTPRequestsFactory)
@interface AMAHTTPRequestsFactory : NSObject

- (AMAHTTPRequestor *)requestorForRequest:(id<AMARequest>)request;

@end

NS_ASSUME_NONNULL_END
