
#import <Foundation/Foundation.h>
#import "AMACore.h"

@protocol AMAKeyValueStoring;
@protocol AMADatabaseProtocol;
@protocol AMAKeyValueStorageProviding;
@class AMAFMDatabase;

@protocol AMADatabaseKeyValueStorageProviding <AMAKeyValueStorageProviding>

- (void)setDatabase:(id<AMADatabaseProtocol>)database;

- (id<AMAKeyValueStoring>)storageForDB:(AMAFMDatabase *)db;

- (id<AMAKeyValueStoring>)nonPersistentStorageForKeys:(NSArray *)keys db:(AMAFMDatabase *)db error:(NSError **)error;
- (BOOL)saveStorage:(id<AMAKeyValueStoring>)storage db:(AMAFMDatabase *)db error:(NSError **)error;

- (void)addBackingKeys:(NSArray<NSString *> *)backingKeys;

@end
