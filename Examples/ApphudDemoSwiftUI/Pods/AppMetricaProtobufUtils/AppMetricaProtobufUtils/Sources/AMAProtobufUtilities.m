
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>

@implementation AMAProtobufUtilities

+ (void *)addBuffer:(const void *)buffer ofSize:(NSUInteger)size toTracker:(id<AMAAllocationsTracking>)tracker
{
    void *outBuffer = NULL;
    if (buffer != NULL) {
        outBuffer = [tracker allocateSize:size];
        if (outBuffer != NULL) {
            memcpy(outBuffer, buffer, size);
        }
    }

    return outBuffer;
}

+ (char *)addString:(const char *)inputStr toTracker:(id<AMAAllocationsTracking>)tracker
{
    char *outStr = NULL;
    if (inputStr != NULL) {
        outStr = [self addBuffer:inputStr
                          ofSize:sizeof(char) * strlen(inputStr) + sizeof(char)
                       toTracker:tracker];
    }
    return outStr;
}

+ (char *)addNSString:(NSString *)inputStr toTracker:(id<AMAAllocationsTracking>)tracker
{
    return [[self class] addString:[inputStr cStringUsingEncoding:NSUTF8StringEncoding]
                         toTracker:tracker];
}

+ (BOOL)fillBinaryData:(ProtobufCBinaryData *)binaryData
            withString:(NSString *)string
               tracker:(id<AMAAllocationsTracking>)tracker
{
    return [[self class] fillBinaryData:binaryData
                               withData:[string dataUsingEncoding:NSUTF8StringEncoding]
                                tracker:tracker];
}

+ (BOOL)fillBinaryData:(ProtobufCBinaryData *)binaryData
              withData:(NSData *)data
               tracker:(id<AMAAllocationsTracking>)tracker
{
    if (binaryData == NULL || data == nil) {
        return NO;
    }
    BOOL isSuccess = YES;
    size_t dataLength = data.length;
    binaryData->len = dataLength;
    if (dataLength != 0) {
        void *buffer = [self addBuffer:data.bytes ofSize:dataLength toTracker:tracker];
        isSuccess = buffer != NULL;
        binaryData->data = buffer;
    }
    return isSuccess;
}

+ (NSString *)stringForBinaryData:(const ProtobufCBinaryData *)binaryData
{
    return [self stringForBinaryData:binaryData has:YES];
}

+ (NSString *)stringForBinaryData:(const ProtobufCBinaryData *)binaryData has:(protobuf_c_boolean)has
{
    if (has == false || binaryData == NULL) {
        return nil;
    }
    return [[NSString alloc] initWithBytes:binaryData->data length:binaryData->len encoding:NSUTF8StringEncoding];
}

+ (NSData *)dataForBinaryData:(const ProtobufCBinaryData *)binaryData
{
    return [self dataForBinaryData:binaryData has:YES];
}

+ (NSData *)dataForBinaryData:(const ProtobufCBinaryData *)binaryData has:(protobuf_c_boolean)has
{
    if (has == false || binaryData == NULL) {
        return nil;
    }
    return [[NSData alloc] initWithBytes:binaryData->data length:binaryData->len];
}

+ (BOOL)boolForProto:(protobuf_c_boolean)value
{
    return value ? YES : NO;
}

@end
