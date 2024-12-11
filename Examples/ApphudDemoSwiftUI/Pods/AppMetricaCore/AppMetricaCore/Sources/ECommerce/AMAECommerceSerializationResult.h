
#import <Foundation/Foundation.h>

@interface AMAECommerceSerializationResult : NSObject

@property (nonatomic, copy, readonly) NSData *data;
@property (nonatomic, assign, readonly) NSUInteger bytesTruncated;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

- (instancetype)initWithData:(NSData *)data
              bytesTruncated:(NSUInteger)bytesTruncated;

@end
