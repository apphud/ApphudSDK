
#import "AMAStartEventValueSerializer.h"
#import "EventStart.pb-c.h"
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>

@implementation AMAStartEventValueSerializer

- (NSData *)dataForUUIDs:(NSArray<NSString *> *)uuids
{
    NSData *__block data = nil;
    
    [AMAAllocationsTrackerProvider track:^(id<AMAAllocationsTracking> tracker) {
        AmaStartEvent__Value value = AMA_START_EVENT__VALUE__INIT;
        
        value.binary_images = (AmaStartEvent__Value__BinaryImage **)
            [tracker allocateSize:sizeof(AmaStartEvent__Value__BinaryImage *) * uuids.count];
        
        NSUInteger count = 0;
        
        for (NSString *uuid in uuids) {
            value.binary_images[count] =
                (AmaStartEvent__Value__BinaryImage *)[tracker allocateSize:sizeof(AmaStartEvent__Value__BinaryImage)];
            ama_start_event__value__binary_image__init(value.binary_images[count]);
            BOOL isSuccess = [AMAProtobufUtilities fillBinaryData:&value.binary_images[count]->uuid
                                                       withString:uuid
                                                          tracker:tracker];
            if (isSuccess) {
                count++;
            }
        }
        
        value.n_binary_images = count;
        
        size_t dataSize = ama_start_event__value__get_packed_size(&value);
        uint8_t *bytes = (uint8_t *)malloc(dataSize);
        ama_start_event__value__pack(&value, bytes);
        data = [NSData dataWithBytesNoCopy:bytes length:dataSize];
    }];
    
    return data;
}

@end
