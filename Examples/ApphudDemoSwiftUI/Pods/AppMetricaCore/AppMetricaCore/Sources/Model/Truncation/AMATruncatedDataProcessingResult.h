
#import <Foundation/Foundation.h>

@interface AMATruncatedDataProcessingResult : NSObject

@property (nonatomic, copy, readonly) NSData *data;
@property (nonatomic, assign, readonly) NSUInteger bytesTruncated;

+ (instancetype)new NS_UNAVAILABLE;
- (instancetype)init NS_UNAVAILABLE;

- (instancetype)initWithData:(NSData *)data
              bytesTruncated:(NSUInteger)bytesTruncated;

@end
