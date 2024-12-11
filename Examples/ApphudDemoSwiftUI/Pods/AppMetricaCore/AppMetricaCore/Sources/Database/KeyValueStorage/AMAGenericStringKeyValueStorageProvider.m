
#import "AMAGenericStringKeyValueStorageProvider.h"
#import "AMAStringDatabaseKeyValueStorageConverter.h"
#import "AMASyncKeyValueStorageDataProvider.h"
#import "AMAInMemoryKeyValueStorageDataProvider.h"
#import "AMAKeyValueStorage.h"
#import "AMACachingKeyValueStorage.h"

@interface AMAGenericStringKeyValueStorageProvider ()

@property (nonatomic, strong, readonly) id<AMAKeyValueStorageConverting> converter;
@property (nonatomic, strong, readonly) id<AMAKeyValueStorageDataProviding> dataProvider;

@end

@implementation AMAGenericStringKeyValueStorageProvider

@synthesize syncStorage = _syncStorage;
@synthesize cachingStorage = _cachingStorage;

- (instancetype)initWithDataProvider:(id<AMAKeyValueStorageDataProviding>)dataProvider
{
    self = [super init];
    if (self != nil) {
        _converter = [[AMAStringDatabaseKeyValueStorageConverter alloc] init];
        _dataProvider = dataProvider;

        __weak typeof(self) weakSelf = self;
        AMAKVSProviderSource providerSource = ^(AMAKVSWithProviderBlock block) {
            block(weakSelf.dataProvider);
        };
        id<AMAKeyValueStorageDataProviding> syncProvider =
            [[AMASyncKeyValueStorageDataProvider alloc] initWithUnderlyingProviderSource:providerSource];
        _syncStorage = [[AMAKeyValueStorage alloc] initWithDataProvider:syncProvider converter:_converter];

        AMACachingKeyValueStorage *cachingStorage = [[AMACachingKeyValueStorage alloc] initWithStorage:_syncStorage];
        [cachingStorage flush]; // This part of caching storage is irrelevant here so we force writes
        _cachingStorage = cachingStorage;
    }
    return self;
}

- (void)inStorage:(void (^)(id<AMAKeyValueStoring>))block
{
    if (block != nil) {
        block(self.syncStorage);
    }
}

- (id<AMAKeyValueStoring>)emptyNonPersistentStorage
{
    return [[AMAKeyValueStorage alloc] initWithDataProvider:[[AMAInMemoryKeyValueStorageDataProvider alloc] init]
                                                  converter:self.converter];
}

- (id<AMAKeyValueStoring>)nonPersistentStorageForKeys:(NSArray *)keys error:(NSError **)error
{
    id<AMAKeyValueStoring> result = nil;
    NSDictionary *objects = [self.dataProvider objectsForKeys:keys error:error];
    if (objects != nil) {
        AMAInMemoryKeyValueStorageDataProvider *provider =
            [[AMAInMemoryKeyValueStorageDataProvider alloc] initWithDictionary:[objects mutableCopy]];
        result = [[AMAKeyValueStorage alloc] initWithDataProvider:provider converter:self.converter];
    }
    return result;
}

- (id<AMAKeyValueStoring>)nonPersistentStorageForStorage:(AMAKeyValueStorage *)storage error:(NSError **)error
{
    if ([self validateStorage:storage error:error] == NO) {
        return nil;
    }

    id<AMAKeyValueStoring> result = nil;
    NSArray *allKeys = [storage.dataProvider allKeysWithError:error];
    if (allKeys != nil) {
        NSDictionary *objects = [self.dataProvider objectsForKeys:allKeys error:error];
        if (objects != nil) {
            AMAInMemoryKeyValueStorageDataProvider *provider =
                [[AMAInMemoryKeyValueStorageDataProvider alloc] initWithDictionary:[objects mutableCopy]];
            result = [[AMAKeyValueStorage alloc] initWithDataProvider:provider converter:self.converter];
        }
    }
    return result;
}

- (BOOL)saveStorage:(AMAKeyValueStorage *)storage error:(NSError **)error
{
    if ([self validateStorage:storage error:error] == NO) {
        return NO;
    }

    BOOL result = NO;
    NSArray *allKeys = [storage.dataProvider allKeysWithError:error];
    if (allKeys != nil) {
        NSDictionary *objects = [storage.dataProvider objectsForKeys:allKeys error:error];
        if (objects != nil) {
            result = [self.dataProvider saveObjectsDictionary:objects error:error];
        }
    }
    return result;
}

- (BOOL)validateStorage:(AMAKeyValueStorage *)storage error:(NSError **)error
{
    if ([storage isKindOfClass:[AMAKeyValueStorage class]] == NO) {
        AMALogAssert(@"Invalid storage type");
        [AMAErrorUtilities fillError:error withInternalErrorName:@"Invalid storage type"];
        return NO;
    }
    if (storage.converter != self.converter) {
        AMALogAssert(@"Invalid converter. Are you trying to use storage from a different provider?");
        [AMAErrorUtilities fillError:error withInternalErrorName:@"Invalid converter"];
        return NO;
    }
    return YES;
}

@end
