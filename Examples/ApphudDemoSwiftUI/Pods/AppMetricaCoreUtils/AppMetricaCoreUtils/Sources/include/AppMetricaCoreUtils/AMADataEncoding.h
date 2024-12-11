
#import <Foundation/Foundation.h>

NS_SWIFT_NAME(DataEncoding)
@protocol AMADataEncoding <NSObject>

- (NSData *)encodeData:(NSData *)data error:(NSError **)error;
- (NSData *)decodeData:(NSData *)data error:(NSError **)error;

@end
