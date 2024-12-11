
#import "AMAECommerceSerializationResult.h"

@implementation AMAECommerceSerializationResult

- (instancetype)initWithData:(NSData *)data
              bytesTruncated:(NSUInteger)bytesTruncated
{
    self = [super init];
    if (self != nil) {
        _data = [data copy];
        _bytesTruncated = bytesTruncated;
    }
    return self;
}

@end
