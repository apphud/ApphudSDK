
#import "AMACore.h"
#import "AMAEventNameHashesStorage.h"
#import "AMAEventNameHashesCollection.h"
#import "AMAEventNameHashesSerializer.h"

@interface AMAEventNameHashesStorage ()

@property (nonatomic, strong, readonly) id<AMAFileStorage> fileStorage;
@property (nonatomic, strong, readonly) AMAEventNameHashesSerializer *serializer;

@end

@implementation AMAEventNameHashesStorage

- (instancetype)initWithFileStorage:(id<AMAFileStorage>)fileStorage
{
    return [self initWithFileStorage:fileStorage
                          serializer:[[AMAEventNameHashesSerializer alloc] init]];
}

- (instancetype)initWithFileStorage:(id<AMAFileStorage>)fileStorage
                         serializer:(AMAEventNameHashesSerializer *)serializer
{
    self = [super init];
    if (self != nil) {
        _fileStorage = fileStorage;
        _serializer = serializer;
    }
    return self;
}

- (BOOL)saveCollection:(AMAEventNameHashesCollection *)collection
{
    NSData *data = [self.serializer dataForCollection:collection];
    NSError *error = nil;
    BOOL result = [self.fileStorage writeData:data error:&error];
    if (result == NO) {
        AMALogWarn(@"Failed to write event name hashes collection: %@", error);
    }
    return result;
}

- (AMAEventNameHashesCollection *)loadCollection
{
    AMAEventNameHashesCollection *collection = nil;
    NSError *error = nil;
    NSData *data = [self.fileStorage readDataWithError:&error];
    if (data.length > 0) {
        collection = [self.serializer collectionForData:data];
    }
    else {
        AMALogWarn(@"Failed to read event name hashes collection: %@", error);
    }
    return collection;
}


@end
