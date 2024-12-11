
#import <Foundation/Foundation.h>

@class AMAHTTPRequestsFactory;
@protocol AMARequest;
@protocol AMAAsyncExecuting;
@protocol AMAIterable;
@protocol AMAHostExchangeResponseValidating;

extern NSErrorDomain const kAMAHostExchangeRequestProcessorErrorDomain 
    NS_SWIFT_NAME(HostExchangeRequestProcessorErrorDomain);

typedef NS_ERROR_ENUM(kAMAHostExchangeRequestProcessorErrorDomain, AMAHostExchangeRequestProcessorErrorCode) {
    AMAHostExchangeRequestProcessorNetworkError,
    AMAHostExchangeRequestProcessorBadRequest,
} NS_SWIFT_NAME(HostExchangeRequestProcessorErrorCode);

typedef void(^AMAHostExchangeRequestProcessorCallback)(NSError *error)
    NS_SWIFT_UNAVAILABLE("Use Swift closures.");

NS_SWIFT_NAME(HostExchangeRequestProcessor)
@interface AMAHostExchangeRequestProcessor : NSObject

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithRequest:(id<AMARequest>)request
                       executor:(id<AMAAsyncExecuting>)executor
                   hostProvider:(id<AMAIterable>)hostProvider
              responseValidator:(id<AMAHostExchangeResponseValidating>)responseValidator;
- (instancetype)initWithRequest:(id<AMARequest>)request
                       executor:(id<AMAAsyncExecuting>)executor
                   hostProvider:(id<AMAIterable>)hostProvider
              responseValidator:(id<AMAHostExchangeResponseValidating>)responseValidator
            httpRequestsFactory:(AMAHTTPRequestsFactory *)httpRequestsFactory;

- (void)processWithCallback:(AMAHostExchangeRequestProcessorCallback)callback;

@end
