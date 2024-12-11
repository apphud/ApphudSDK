
#import "AMADatabaseKeyValueStorageProvider.h"
#import "AMADatabaseProtocol.h"
#import "AMAKeyValueStorage.h"
#import "AMASyncKeyValueStorageDataProvider.h"
#import "AMADatabaseKVSDataProvider.h"
#import "AMAInMemoryKeyValueStorageDataProvider.h"
#import "AMACachingKeyValueStorage.h"
#import "AMABackingKVSDataProvider.h"
#import "AMADatabaseConstants.h"

@interface AMADatabaseKeyValueStorageProvider ()

@property (nonatomic, copy, readonly) NSString *tableName;
@property (nonatomic, strong, readonly) id<AMAKeyValueStorageConverting> converter;
@property (nonatomic, copy, readonly) AMADatabaseObjectProviderBlock objectProvider;
@property (nonatomic, strong, readonly) AMACachingKeyValueStorage *cachingStorageInstance;

@property (nonatomic, strong, readonly) id<AMAKeyValueStorageDataProviding> backingDataProvider;

@property (atomic, strong) NSArray<NSString *> *backingKeys;

@end

@implementation AMADatabaseKeyValueStorageProvider

@synthesize syncStorage = _syncStorage;

- (instancetype)initWithTableName:(NSString *)tableName
                        converter:(id<AMAKeyValueStorageConverting>)converter
                   objectProvider:(AMADatabaseObjectProviderBlock)objectProvider
           backingKVSDataProvider:(id<AMAKeyValueStorageDataProviding>)backingDataProvider
{
    self = [super init];
    if (self != nil) {
        _tableName = [tableName copy];
        _converter = converter;
        _objectProvider = [objectProvider copy];
        _backingDataProvider = backingDataProvider;
        _backingKeys = @[ kAMADatabaseKeyLibraryVersion ];

        __weak typeof(self) weakSelf = self;
        AMAKVSProviderSource providerSource = ^(AMAKVSWithProviderBlock block) {
            [weakSelf.database inDatabase:^(AMAFMDatabase *db) {
                block([weakSelf dataProviderForDB:db]);
            }];
        };
        id<AMAKeyValueStorageDataProviding> syncProvider =
            [[AMASyncKeyValueStorageDataProvider alloc] initWithUnderlyingProviderSource:providerSource];
        _syncStorage = [[AMAKeyValueStorage alloc] initWithDataProvider:syncProvider
                                                              converter:converter];

        _cachingStorageInstance = [[AMACachingKeyValueStorage alloc] initWithStorage:_syncStorage];
    }
    return self;
}

- (void)setDatabase:(id<AMADatabaseProtocol>)database
{
    if (_database != database) {
        _database = database;
        [database executeWhenOpen:^{
            AMALogInfo(@"DB is open, flushing cache");
            [self.cachingStorageInstance flush];
        }];
    }
}

- (id<AMAKeyValueStoring>)cachingStorage
{
    return self.cachingStorageInstance;
}

- (void)inStorage:(void (^)(id<AMAKeyValueStoring> storage))block
{
    [self.database inDatabase:^(AMAFMDatabase *db) {
        if (block != nil) {
            block([self storageForDB:db]);
        }
    }];
}

- (id<AMAKeyValueStoring>)storageForDB:(AMAFMDatabase *)db
{
    return [[AMAKeyValueStorage alloc] initWithDataProvider:[self dataProviderForDB:db]
                                                  converter:self.converter];
}

- (id<AMAKeyValueStorageDataProviding>)dataProviderForDB:(AMAFMDatabase *)db
{
    AMADatabaseKVSDataProvider *dbDataProvider =
        [[AMADatabaseKVSDataProvider alloc] initWithDatabase:db
                                                   tableName:self.tableName
                                              objectProvider:self.objectProvider];
    
    if (self.backingDataProvider != nil) {
        __weak typeof(self) weakSelf = self;
        __auto_type providerSource = ^(AMAKVSWithProviderBlock block) {
            block(dbDataProvider);
        };
        
        __auto_type backingProviderSource = ^(AMAKVSWithProviderBlock block) {
            block(weakSelf.backingDataProvider);
        };
        
        return [[AMABackingKVSDataProvider alloc] initWithProviderSource:providerSource
                                                   backingProviderSource:backingProviderSource
                                                             backingKeys:self.backingKeys];
    }
    
    return dbDataProvider;
}

- (void)addBackingKeys:(NSArray<NSString *> *)backingKeys
{
    @synchronized (self) {
        self.backingKeys = [self.backingKeys arrayByAddingObjectsFromArray:backingKeys];
    }
}

- (id<AMAKeyValueStoring>)emptyNonPersistentStorage
{
    return [[AMAKeyValueStorage alloc] initWithDataProvider:[[AMAInMemoryKeyValueStorageDataProvider alloc] init]
                                                  converter:self.converter];
}

- (id<AMAKeyValueStoring>)nonPersistentStorageForKeys:(NSArray *)keys error:(NSError **)error
{
    id<AMAKeyValueStoring> __block result = nil;
    NSError *__block internalError = nil;
    [self.database inDatabase:^(AMAFMDatabase *db) {
        result = [self nonPersistentStorageForKeys:keys db:db error:&internalError];
    }];
    if (result == nil) {
        AMALogError(@"Failed to load storage for keys '%@': %@", keys, internalError);
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return result;
}

- (BOOL)saveStorage:(AMAKeyValueStorage *)storage error:(NSError **)error
{
    BOOL __block result = NO;
    NSError *__block internalError = nil;
    [self.database inDatabase:^(AMAFMDatabase *db) {
        result = [self saveStorage:storage db:db error:&internalError];
    }];
    if (result == NO) {
        AMALogError(@"Failed to save storage: %@", internalError);
        [AMAErrorUtilities fillError:error withError:internalError];
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
        NSDictionary *objects = [storage.dataProvider objectsForKeys:allKeys error:error];
        if (objects != nil) {
            AMAInMemoryKeyValueStorageDataProvider *provider =
                [[AMAInMemoryKeyValueStorageDataProvider alloc] initWithDictionary:[objects mutableCopy]];
            result = [[AMAKeyValueStorage alloc] initWithDataProvider:provider converter:self.converter];
        }
    }
    return result;
}

- (id<AMAKeyValueStoring>)nonPersistentStorageForKeys:(NSArray *)keys db:(AMAFMDatabase *)db error:(NSError **)error
{
    id<AMAKeyValueStoring> result = nil;
    id<AMAKeyValueStorageDataProviding> dataProvider = [self dataProviderForDB:db];
    NSDictionary *objects = [dataProvider objectsForKeys:keys error:error];
    if (objects != nil) {
        AMAInMemoryKeyValueStorageDataProvider *provider =
            [[AMAInMemoryKeyValueStorageDataProvider alloc] initWithDictionary:[objects mutableCopy]];
        result = [[AMAKeyValueStorage alloc] initWithDataProvider:provider converter:self.converter];
    }
    return result;
}

- (BOOL)saveStorage:(AMAKeyValueStorage *)storage db:(AMAFMDatabase *)db error:(NSError **)error
{
    if ([self validateStorage:storage error:error] == NO) {
        return NO;
    }

    BOOL result = NO;
    id<AMAKeyValueStorageDataProviding> dataProvider = [self dataProviderForDB:db];
    NSArray *allKeys = [storage.dataProvider allKeysWithError:error];
    if (allKeys != nil) {
        NSDictionary *objects = [storage.dataProvider objectsForKeys:allKeys error:error];
        if (objects != nil) {
            result = [dataProvider saveObjectsDictionary:objects error:error];
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
