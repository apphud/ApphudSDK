
#import "AMACore.h"
#import "AMAEventFirstOccurrenceController.h"
#import "AMAEventNameHashesStorage.h"
#import "AMAEventNameHashesCollection.h"
#import "AMAEventNameHashProvider.h"
#import "AMAMetricaConfiguration.h"
#import "AMAMetricaInMemoryConfiguration.h"

static NSUInteger const kAMAMaxEventNameHashesCount = 1000;

@interface AMAEventFirstOccurrenceController ()

@property (nonatomic, strong, readonly) AMAEventNameHashesStorage *storage;
@property (nonatomic, strong, readonly) AMAEventNameHashProvider *hashProvider;
@property (nonatomic, assign, readonly) NSUInteger maxEventHashesCount;

@property (nonatomic, strong) AMAEventNameHashesCollection *collection;

@end

@implementation AMAEventFirstOccurrenceController

- (instancetype)initWithStorage:(AMAEventNameHashesStorage *)storage
{
    return [self initWithStorage:storage
                    hashProvider:[[AMAEventNameHashProvider alloc] init]
             maxEventHashesCount:kAMAMaxEventNameHashesCount];
}

- (instancetype)initWithStorage:(AMAEventNameHashesStorage *)storage
                   hashProvider:(AMAEventNameHashProvider *)hashProvider
            maxEventHashesCount:(NSUInteger)maxEventHashesCount
{
    self = [super init];
    if (self != nil) {
        _storage = storage;
        _hashProvider = hashProvider;
        _maxEventHashesCount = maxEventHashesCount;
    }
    return self;
}

+ (NSString *)currentVersion
{
    NSString *appVersion = [AMAMetricaConfiguration sharedInstance].inMemory.appVersion;
    uint32_t appBuildNumber = [AMAMetricaConfiguration sharedInstance].inMemory.appBuildNumber;
    return [NSString stringWithFormat:@"%@_%u", appVersion, appBuildNumber];
}

- (AMAEventNameHashesCollection *)collection
{
    if (_collection == nil) {
        AMALogInfo(@"Loading collection");
        _collection = [self.storage loadCollection];
        if (_collection == nil) {
            AMALogInfo(@"Saved collection not found. Instantiating new empty one.");
            _collection = [[AMAEventNameHashesCollection alloc] initWithCurrentVersion:[[self class] currentVersion]
                                                         hashesCountFromCurrentVersion:0
                                                              handleNewEventsAsUnknown:YES
                                                                       eventNameHashes:[NSMutableSet set]];
            [self.storage saveCollection:_collection];
        }
    }
    return _collection;
}

- (void)updateVersion
{
    AMAEventNameHashesCollection *collection = self.collection;
    NSString *version = [[self class] currentVersion];
    if (version != collection.currentVersion && [version isEqualToString:collection.currentVersion] == NO) {
        AMALogInfo(@"Change current version from '%@' to '%@'", collection.currentVersion, version);
        collection.currentVersion = version;
        collection.hashesCountFromCurrentVersion = 0;
        [self.storage saveCollection:collection];
    }
}

- (AMAOptionalBool)isEventNameFirstOccurred:(NSString *)eventName
{
    AMAOptionalBool result = AMAOptionalBoolUndefined;
    NSNumber *hash = [self.hashProvider hashForEventName:eventName];
    AMAEventNameHashesCollection *collection = self.collection;
    if ([collection.eventNameHashes containsObject:hash]) {
        result = AMAOptionalBoolFalse;
    }
    else {
        if (collection.handleNewEventsAsUnknown == NO) {
            result = AMAOptionalBoolTrue;
        }
        [self addEventNameHash:hash];
    }
    AMALogInfo(@"Event with name '%@' has occurrence status: %d. Hashes count: %lu (current version: %lu)",
               eventName, (int)result, (unsigned long)collection.eventNameHashes.count,
               (unsigned long)collection.hashesCountFromCurrentVersion);
    return result;
}

- (void)addEventNameHash:(NSNumber *)hash
{
    AMAEventNameHashesCollection *collection = self.collection;
    BOOL collectionChanged = NO;
    if (collection.hashesCountFromCurrentVersion < self.maxEventHashesCount) {
        AMALogInfo(@"New event name");
        [collection.eventNameHashes addObject:hash];
        ++collection.hashesCountFromCurrentVersion;
        collectionChanged = YES;
    }
    else {
        AMALogInfo(@"Can't save event name");
        if (collection.handleNewEventsAsUnknown == NO) {
            collection.handleNewEventsAsUnknown = YES;
            collectionChanged = YES;
        }
    }

    if (collectionChanged) {
        [self.storage saveCollection:collection];
    }
}

- (void)resetHashes
{
    AMALogInfo(@"Reset history");
    AMAEventNameHashesCollection *collection = self.collection;
    [collection.eventNameHashes removeAllObjects];
    collection.hashesCountFromCurrentVersion = 0;
    collection.handleNewEventsAsUnknown = NO;
    [self.storage saveCollection:collection];
}

@end
