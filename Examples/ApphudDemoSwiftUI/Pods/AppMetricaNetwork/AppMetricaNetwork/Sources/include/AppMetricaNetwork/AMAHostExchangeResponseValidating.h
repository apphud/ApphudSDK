
#import <Foundation/Foundation.h>

NS_SWIFT_NAME(HostExchangeResponseValidating)
@protocol AMAHostExchangeResponseValidating <NSObject>

- (BOOL)isResponseValidWithData:(NSData *)data;

@end
