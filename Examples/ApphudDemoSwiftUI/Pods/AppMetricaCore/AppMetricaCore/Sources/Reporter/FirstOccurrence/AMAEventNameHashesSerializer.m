
#import "AMACore.h"
#import "AMAEventNameHashesSerializer.h"
#import "AMAEventNameHashesCollection.h"
#import "EventNameHashesCollection.pb-c.h"
#import <AppMetricaProtobufUtils/AppMetricaProtobufUtils.h>

@implementation AMAEventNameHashesSerializer

#pragma mark - Serialization

- (NSData *)dataForCollection:(AMAEventNameHashesCollection *)collection
{
    NSData *__block packedState = nil;
    [AMAAllocationsTrackerProvider track:^(id<AMAAllocationsTracking> tracker) {
        Ama__EventNameHashesCollection result = AMA__EVENT_NAME_HASHES_COLLECTION__INIT;
        [AMAProtobufUtilities fillBinaryData:&result.current_version
                                  withString:collection.currentVersion
                                     tracker:tracker];
        result.hashes_count_from_current_version = (uint32_t)collection.hashesCountFromCurrentVersion;
        result.handle_new_events_as_unknown = (protobuf_c_boolean)collection.handleNewEventsAsUnknown;
        
        NSUInteger hashesCount = collection.eventNameHashes.count;
        result.n_event_name_hashes = hashesCount;
        result.event_name_hashes = [tracker allocateSize:sizeof(uint64_t) * hashesCount];
        NSUInteger __block idx = 0;
        for (NSNumber *hash in collection.eventNameHashes) {
            result.event_name_hashes[idx] = (uint64_t)[hash unsignedLongLongValue];
            ++idx;
        }
        packedState = [self packState:&result];
    }];
    
    return packedState;
}

- (NSData *)packState:(Ama__EventNameHashesCollection *)collection
{
    size_t dataSize = ama__event_name_hashes_collection__get_packed_size(collection);
    void *buffer = malloc(dataSize);
    ama__event_name_hashes_collection__pack(collection, buffer);
    NSData *data = [NSData dataWithBytesNoCopy:buffer length:dataSize];
    return data;
}

#pragma mark - Deserialization

- (AMAEventNameHashesCollection *)collectionForData:(NSData *)data
{
    AMAEventNameHashesCollection *result = nil;
    NS_VALID_UNTIL_END_OF_SCOPE AMAProtobufAllocator *allocator = [[AMAProtobufAllocator alloc] init];
    Ama__EventNameHashesCollection *collection =
        ama__event_name_hashes_collection__unpack([allocator protobufCAllocator], data.length, data.bytes);
    
    if (collection != NULL) {
        NSString *currentVersion = [AMAProtobufUtilities stringForBinaryData:&collection->current_version];
        NSUInteger hashesCountFromCurrentVersion = (NSUInteger)collection->hashes_count_from_current_version;
        BOOL handleNewEventsAsUnknown = (BOOL)collection->handle_new_events_as_unknown;
        NSMutableSet *eventNameHashes = [NSMutableSet set];
        for (NSUInteger idx = 0; idx < collection->n_event_name_hashes; ++idx) {
            NSNumber *hash = [NSNumber numberWithUnsignedLongLong:collection->event_name_hashes[idx]];
            [eventNameHashes addObject:hash];
        }
        
        result = [[AMAEventNameHashesCollection alloc] initWithCurrentVersion:currentVersion
                                                hashesCountFromCurrentVersion:hashesCountFromCurrentVersion
                                                     handleNewEventsAsUnknown:handleNewEventsAsUnknown
                                                              eventNameHashes:eventNameHashes];
    }
    else {
        AMALogError(@"Invalid event name hashes data");
    }
    return result;
}

@end
