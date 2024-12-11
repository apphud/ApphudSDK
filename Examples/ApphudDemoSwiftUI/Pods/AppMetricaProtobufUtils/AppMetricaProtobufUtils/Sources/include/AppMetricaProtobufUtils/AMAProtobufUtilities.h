#import <Foundation/Foundation.h>
#import <AppMetricaProtobuf/AppMetricaProtobuf.h>

NS_ASSUME_NONNULL_BEGIN

@protocol AMAAllocationsTracking;

NS_SWIFT_NAME(ProtobufUtilities)
@interface AMAProtobufUtilities : NSObject

+ (void *)addBuffer:(nullable const void *)buffer ofSize:(NSUInteger)size toTracker:(id<AMAAllocationsTracking>)tracker;
+ (char *)addString:(nullable const char *)inputStr toTracker:(id<AMAAllocationsTracking>)tracker;
+ (char *)addNSString:(NSString *)inputStr toTracker:(id<AMAAllocationsTracking>)tracker;

+ (BOOL)fillBinaryData:(nullable ProtobufCBinaryData *)binaryData
            withString:(NSString *)string
               tracker:(id<AMAAllocationsTracking>)tracker;
+ (BOOL)fillBinaryData:(nullable ProtobufCBinaryData *)binaryData
              withData:(nullable NSData *)data
               tracker:(id<AMAAllocationsTracking>)tracker;

+ (NSString *)stringForBinaryData:(nullable const ProtobufCBinaryData *)binaryData;
+ (NSString *)stringForBinaryData:(nullable const ProtobufCBinaryData *)binaryData has:(protobuf_c_boolean)has;

+ (NSData *)dataForBinaryData:(nullable const ProtobufCBinaryData *)binaryData;
+ (NSData *)dataForBinaryData:(nullable const ProtobufCBinaryData *)binaryData has:(protobuf_c_boolean)has;

+ (BOOL)boolForProto:(protobuf_c_boolean)value;

- (instancetype)init NS_UNAVAILABLE;
+ (instancetype)new NS_UNAVAILABLE;

@end

NS_ASSUME_NONNULL_END
