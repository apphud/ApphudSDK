
#import "AMACore.h"
#import "AMADatabaseKVSDataProvider.h"
#import "AMADatabaseConstants.h"
#import <AppMetricaFMDB/AppMetricaFMDB.h>

@interface AMADatabaseKVSDataProvider ()

@property (nonatomic, strong, readonly) AMAFMDatabase *database;
@property (nonatomic, copy, readonly) NSString *tableName;
@property (nonatomic, copy, readonly) AMADatabaseObjectProviderBlock objectProvider;

@end

@implementation AMADatabaseKVSDataProvider

- (instancetype)initWithDatabase:(AMAFMDatabase *)database
                       tableName:(NSString *)tableName
                  objectProvider:(AMADatabaseObjectProviderBlock)objectProvider
{
    self = [super init];
    if (self != nil) {
        _database = database;
        _tableName = [tableName copy];
        _objectProvider = [objectProvider copy];
    }
    return self;
}

- (NSArray<NSString *> *)allKeysWithError:(NSError **)error
{
    NSMutableArray<NSString *> *result = [NSMutableArray array];
    NSString *query = [NSString stringWithFormat:@"SELECT %@ FROM %@", kAMAKeyValueTableFieldKey, self.tableName];
    NSError *internalError = nil;
    AMAFMResultSet *rs = [self.database executeQuery:query values:@[] error:&internalError];
    while (internalError == nil && [rs nextWithError:&internalError]) {
        NSString *key = [rs stringForColumnIndex:0];
        if (key != nil && (id)key != [NSNull null]) {
            [result addObject:key];
        }
    }
    [rs close];
    if (internalError != nil) {
        result = nil;
        AMALogError(@"Failed to load all keys");
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return [result copy];
}

- (BOOL)removeKey:(NSString *)key error:(NSError **)error
{
    NSError *internalError = nil;
    NSString *query = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ = ?",
                       self.tableName, kAMAKeyValueTableFieldKey];
    BOOL success = [self.database executeUpdate:query values:@[ key ] error:&internalError];
    if (success == NO) {
        AMALogError(@"Failed to remove string for key '%@': %@", key, internalError);
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return success;
}

- (id)objectForKey:(NSString *)key error:(NSError **)error
{
    id result = nil;
    NSError *internalError = nil;
    NSString *query = [NSString stringWithFormat:@"SELECT %@ FROM %@ WHERE %@ = ? LIMIT 1",
                       kAMAKeyValueTableFieldValue, self.tableName, kAMAKeyValueTableFieldKey];
    AMAFMResultSet *rs = [self.database executeQuery:query values:@[ key ] error:&internalError];
    if (internalError == nil && [rs nextWithError:&internalError]) {
        result = self.objectProvider(rs, 0);
        if (result == [NSNull null]) {
            result = nil;
        }
    }
    [rs close];
    if (internalError != nil) {
        AMALogError(@"Failed to read value for key '%@': %@", key, internalError);
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return result;
}

- (BOOL)saveObject:(id)object forKey:(NSString *)key error:(NSError **)error
{
    if (object == nil) {
        return [self removeKey:key error:error];
    }

    NSError *internalError = nil;
    NSString *query = [NSString stringWithFormat:@"INSERT OR REPLACE INTO %@ (%@, %@) VALUES (?, ?)",
                       self.tableName, kAMAKeyValueTableFieldKey, kAMAKeyValueTableFieldValue];
    BOOL success = [self.database executeUpdate:query values:@[ key, object ] error:&internalError];
    if (success == NO) {
        AMALogError(@"Failed to write value for key '%@': %@", key, internalError);
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return success;
}

- (NSDictionary<NSString *, id> *)objectsForKeys:(NSArray *)keys error:(NSError **)error
{
    NSMutableDictionary *result = [NSMutableDictionary dictionary];

    NSMutableArray *queryKeys = [NSMutableArray arrayWithCapacity:keys.count];
    for (NSUInteger index = 0; index < keys.count; ++index) {
        [queryKeys addObject:@"?"];
    }
    NSString *queryKeysSubstring = [queryKeys componentsJoinedByString:@", "];
    NSString *query = [NSString stringWithFormat:@"SELECT %@, %@ FROM %@ WHERE %@ IN (%@)",
                       kAMAKeyValueTableFieldKey,
                       kAMAKeyValueTableFieldValue,
                       self.tableName,
                       kAMAKeyValueTableFieldKey,
                       queryKeysSubstring];

    NSError *internalError = nil;
    AMAFMResultSet *rs = [self.database executeQuery:query values:keys error:&internalError];
    while (internalError == nil && [rs nextWithError:&internalError]) {
        NSString *key = [rs stringForColumnIndex:0];
        id value = self.objectProvider(rs, 1);
        if (key != nil && key != (id)[NSNull null]) {
            result[key] = value ?: [NSNull null];
        }
    }
    [rs close];

    if (internalError != nil) {
        AMALogError(@"Failed to load objects for keys '%@': %@", keys, internalError);
        result = nil;
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return result;
}

- (BOOL)saveObjectsDictionary:(NSDictionary<NSString *, id> *)objectsDictionary error:(NSError **)error
{
    NSUInteger count = objectsDictionary.count;
    NSMutableArray *insertQueryKeys = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray *insertQueryKeysValues = [NSMutableArray arrayWithCapacity:count * 2];
    NSMutableArray *deleteQueryKeys = [NSMutableArray arrayWithCapacity:count];
    NSMutableArray *deleteQueryValues = [NSMutableArray arrayWithCapacity:count];
    [objectsDictionary enumerateKeysAndObjectsUsingBlock:^(NSString *key, id value, BOOL *stop) {
        if (value == [NSNull null]) {
            [deleteQueryKeys addObject:@"?"];
            [deleteQueryValues addObject:key];
        }
        else {
            [insertQueryKeys addObject:@"(?, ?)"];
            [insertQueryKeysValues addObject:key];
            [insertQueryKeysValues addObject:value];
        }
    }];

    NSError *internalError = nil;
    if (insertQueryKeys.count != 0) {
        NSString *query = [NSString stringWithFormat:@"INSERT OR REPLACE INTO %@ (%@, %@) VALUES %@",
                           kAMAKeyValueTableName,
                           kAMAKeyValueTableFieldKey,
                           kAMAKeyValueTableFieldValue,
                           [insertQueryKeys componentsJoinedByString:@", "]];
        [self.database executeUpdate:query values:insertQueryKeysValues error:&internalError];
    }
    if (internalError == nil && deleteQueryKeys.count != 0) {
        NSString *query = [NSString stringWithFormat:@"DELETE FROM %@ WHERE %@ IN (%@)",
                           kAMAKeyValueTableName,
                           kAMAKeyValueTableFieldKey,
                           [deleteQueryKeys componentsJoinedByString:@", "]];
        [self.database executeUpdate:query values:deleteQueryValues error:&internalError];
    }

    if (internalError != nil) {
        AMALogError(@"Failed to write objects '%@': %@", objectsDictionary, internalError);
        [AMAErrorUtilities fillError:error withError:internalError];
    }
    return internalError == nil;
}

@end
