
#import <Foundation/Foundation.h>

NS_ASSUME_NONNULL_BEGIN

@class AMAHTTPRequestor;
@class AMAHTTPSessionProvider;
@protocol AMARequest;
@protocol AMAAsyncExecuting;
@protocol AMANetworkSessionProviding;

NS_SWIFT_NAME(HTTPRequestDelegate)
@protocol AMAHTTPRequestDelegate <NSObject>

- (void)httpRequestor:(AMAHTTPRequestor *)requestor
    didFinishWithData:(nullable NSData *)data
             response:(nullable NSHTTPURLResponse *)response;

- (void)httpRequestor:(AMAHTTPRequestor *)requestor
   didFinishWithError:(NSError *)error
             response:(nullable NSHTTPURLResponse *)response;

@end

NS_SWIFT_NAME(HTTPRequestor)
@interface AMAHTTPRequestor : NSObject

@property (nonatomic, copy, readonly) id<AMARequest> request;
@property (nonatomic, nullable, weak) id<AMAHTTPRequestDelegate> delegate;
@property (nonatomic, nullable, strong) id<AMAAsyncExecuting> delegateExecutor;

+ (instancetype)requestorWithRequest:(id<AMARequest>)request;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithRequest:(id<AMARequest>)request;
- (instancetype)initWithRequest:(id<AMARequest>)request
                sessionProvider:(id<AMANetworkSessionProviding>)sessionProvider NS_DESIGNATED_INITIALIZER;

- (void)start;
- (void)cancel;

@end

NS_ASSUME_NONNULL_END
