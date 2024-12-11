
#import <Foundation/Foundation.h>
#import <AppMetricaProtobuf/AppMetricaProtobuf.h>

NS_SWIFT_NAME(ProtobufAllocator)
@interface AMAProtobufAllocator : NSObject

- (ProtobufCAllocator *)protobufCAllocator;

@end
